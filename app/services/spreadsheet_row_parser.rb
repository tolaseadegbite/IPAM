require "creek"

# Reads the two estate inventory workbooks from disk and returns one
# normalized entry per IP cell. Each entry carries its sheet row id so the
# importer can group the data-IP and internet-IP of one workstation into a
# single device. No database access here: pure parsing + normalization.
class SpreadsheetRowParser
  INVENTORY_PATH = Rails.root.join("db/imports/inventory_record.xlsx").freeze
  INTERNET_PATH = Rails.root.join("db/imports/internet_ip_address.xlsx").freeze

  IP_RE = /\A\d{1,3}(\.\d{1,3}){3}\z/.freeze
  MAC_RE = /\A([0-9a-f]{2}[:-]){5}[0-9a-f]{2}\z/i.freeze
  SKIP_IPS = %w[255.255.255.0].freeze

  # Cells that hold 172.16.24.89 are a typo for 172.16.242.89 (confirmed).
  IP_TYPOS = { "172.16.24.89" => "172.16.242.89" }.freeze

  # The MIKROTIK sheet holds bare numbers (13.156, 14.155): they are normal
  # assigned rows on the matching estate subnets.
  MIKROTIK_ROWS = [
    { ip: "192.168.13.156", device_text: "MIKROTIK" },
    { ip: "192.168.14.155", device_text: "MIKROTIK" }
  ].freeze

  Entry = Data.define(
    :source, :sheet, :row_id, :ip, :mac,
    :factory, :device_text, :office_text,
    :user_name, :location, :description, :free
  )

  def self.parse(inventory_path: INVENTORY_PATH, internet_path: INTERNET_PATH)
    new(inventory_path, internet_path).parse
  end

  def initialize(inventory_path, internet_path)
    @inventory_path = inventory_path
    @internet_path = internet_path
  end

  def parse
    entries = []
    entries.concat(parse_inventory)
    entries.concat(parse_internet)
    entries.concat(mikrotik_rows)
    entries
  end

  private

  def parse_inventory
    out = []
    book = Creek::Book.new(@inventory_path.to_s)
    book.sheets.each do |sheet|
      case sheet.name.strip
      when ".13 SERIES" then out.concat(parse_series(sheet, internet_col: "F", office_col: "G"))
      when ".15 SERIES" then out.concat(parse_series(sheet, internet_col: nil, office_col: "F"))
      when "INTERNET IP" then out.concat(parse_internet_sheet(sheet))
      end
    end
    out
  end

  # .13/.15 sheets: C = data IP, D = factory, E = device, F/G = internet IP / office.
  # Creek skips physically-empty rows, so the row index is unreliable:
  # the real Excel row number comes from the cell references. Title and
  # header rows carry no IP in the IP column and fall out naturally.
  def parse_series(sheet, internet_col:, office_col:)
    out = []
    sheet.rows.each do |row|
      number = row_number(row)
      cells = letter_keys(row)
      ip = cells["C"].to_s.strip
      next unless IP_RE.match?(ip)
      factory = cells["D"].to_s.strip.presence
      device_text = cells["E"].to_s.strip.presence
      office_text = cells[office_col].to_s.strip.presence
      free = free_row?(factory, device_text, office_text)
      row_id = "inventory/#{sheet.name.strip}##{number}"
      out << build(source: "inventory", sheet: sheet.name.strip, row_id: row_id,
                    ip: ip, factory: factory, device_text: device_text,
                    office_text: office_text, free: free)
      if internet_col
        net_ip = cells[internet_col].to_s.strip
        if IP_RE.match?(net_ip) && !SKIP_IPS.include?(net_ip)
          out << build(source: "inventory", sheet: sheet.name.strip, row_id: row_id,
                       ip: net_ip, factory: factory, device_text: device_text,
                       office_text: office_text, free: free)
        end
      end
    end
    out
  end

  # INTERNET IP sheet: C = IP, D = factory, E = device, F = office.
  def parse_internet_sheet(sheet)
    out = []
    sheet.rows.each do |row|
      number = row_number(row)
      cells = letter_keys(row)
      ip = cells["C"].to_s.strip
      next unless IP_RE.match?(ip)
      factory = cells["D"].to_s.strip.presence
      device_text = cells["E"].to_s.strip.presence
      office_text = cells["F"].to_s.strip.presence
      next if free_row?(factory, device_text, office_text) && office_text.nil? && device_text.nil?
      out << build(source: "inventory", sheet: "INTERNET IP",
                    row_id: "inventory/INTERNET IP##{number}",
                    ip: ip, factory: factory, device_text: device_text,
                    office_text: office_text, free: free_row?(factory, device_text, office_text))
    end
    out
  end

  # Blackman sheet: A = user, B = model, C = location, D = IP, G = description, I = MAC.
  def parse_internet
    out = []
    book = Creek::Book.new(@internet_path.to_s)
    sheet = book.sheets.first
    sheet.rows.each do |row|
      number = row_number(row)
      cells = letter_keys(row)
      ip = cells["D"].to_s.strip
      next unless IP_RE.match?(ip) && !SKIP_IPS.include?(ip)
      mac = normalize_mac(cells["I"].to_s.strip)
      out << build(source: "blackman", sheet: sheet.name.strip,
                    row_id: "blackman##{number}", ip: ip, mac: mac,
                    user_name: cells["A"].to_s.strip.presence,
                    device_text: cells["B"].to_s.strip.presence,
                    office_text: cells["C"].to_s.strip.presence,
                    location: cells["C"].to_s.strip.presence,
                    description: cells["G"].to_s.strip.presence,
                    free: false)
    end
    out
  end

  def mikrotik_rows
    MIKROTIK_ROWS.map do |row|
      build(source: "inventory", sheet: "MIKROTIK", row_id: "inventory/MIKROTIK##{row[:ip]}",
            ip: row[:ip], device_text: row[:device_text], office_text: "MIKROTIK", free: false)
    end
  end

  def build(source:, sheet:, row_id:, ip:, mac: nil, factory: nil,
            device_text: nil, office_text: nil, user_name: nil,
            location: nil, description: nil, free: false)
    fixed = IP_TYPOS.fetch(ip, ip)
    Entry.new(source: source, sheet: sheet, row_id: row_id, ip: fixed,
              mac: mac, factory: factory, device_text: device_text,
              office_text: office_text, user_name: user_name, location: location,
              description: description, free: free)
  end

  def letter_keys(row)
    row.transform_keys { |key| key.to_s.gsub(/\d+/, "") }
  end

  def row_number(row)
    row.keys.first.to_s.gsub(/\D/, "")
  end

  def free_row?(*texts)
    texts.compact.any? { |text| text.strip.casecmp?("free") }
  end

  def normalize_mac(raw)
    return nil if raw.blank?
    cleaned = raw.strip.downcase.tr("-", ":")
    MAC_RE.match?(cleaned) ? cleaned : nil
  end
end
