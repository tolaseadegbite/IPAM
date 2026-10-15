# One-shot importer for the estate inventory spreadsheets (db/imports/).
#
# Matching is MAC-first: a row carrying a MAC links to the device holding
# that MAC (or creates a device holding it). Rows without a MAC resolve
# through the IP's current link, so a device and its MAC are never split.
# Existing device links always win over sheet text (sheets go stale);
# sheet text is appended to IP notes instead. Existing MACs are never
# overwritten; blank MACs are filled from sheet data.
#
# Run dry-run first (default): SpreadsheetImportService.call(dry_run: true)
class SpreadsheetImportService
  # Factory cell -> Branch name. HEADQUATERS lives under Sumal (confirmed).
  FACTORY_BRANCHES = {
    "YALE 1" => "Yale 1", "YALE 2" => "Yale 2", "YALE 3" => "Yale 3",
    "YALE 4" => "Yale 4", "YALE 5" => "Yale 5", "YALE 8" => "Yale 8",
    "YALE 9" => "Yale 9", "YALE 10" => "Yale 10", "YALE 12" => "Yale 12",
    "YALE 14" => "Yale 14", "YALE" => "Yale 1",
    "HEADQUATERS" => "Sumal", "HEADQUARTERS" => "Sumal", "HEAD OFFICE" => "Sumal",
    "VITAL" => "Vital", "HARVARD" => "Havard",
    "Y2 ENGR RAFU" => "Yale 2"
  }.freeze

  # Office/desk text -> Department name within the branch (typos included:
  # the sheets write FINNACE, PERONNEL, DESKSTOP ...).
  OFFICE_DEPARTMENTS = {
    "ACCT OFFICE" => "Account Office", "ACCOUNT OFFICE" => "Account Office",
    "ACCOUNT" => "Account", "FINANCE OFFICE" => "Finance", "FINANCE" => "Finance",
    "FINNACE" => "Finance", "FINNACE OFFICE" => "Finance",
    "PERSONNEL OFFICE" => "Personnel Office", "PERSONNEL" => "Personnel",
    "PERONNEL" => "Personnel Office", "PERSONEL" => "Personnel",
    "STORE" => "Store", "CENTRAL STORE" => "Store", "MAIN STORE" => "Store",
    "WAREHOUSE" => "Warehouse",
    "MARKETING" => "Marketing", "WAYBILL" => "Waybill",
    "WEIGHBRIDGE" => "Weight Bridge", "WAY BRIDGE" => "Weight Bridge",
    "UTILITY OFFICE" => "UTILITY", "UTILITY" => "UTILITY",
    "AUTOMOBILE" => "Automobile", "ERP OFFICE" => "ERP Office",
    "MIXING SECT" => "Mixing Section", "MIXING" => "Mixing Section",
    "RAW MATERIAL" => "Raw Material", "PALLET GENERATION" => "Pallet Generation",
    "AUDIT" => "Audit", "AUDITOR" => "Audit", "CLINIC" => "Clinic", "SALES" => "Sales"
  }.freeze

  DEVICE_TYPES = {
    "DESKTOP" => "desktop", "DESKSTOP" => "desktop",
    "LAPTOP" => "laptop", "ALL IN ONE" => "all_in_one", "ALL-IN-ONE" => "all_in_one",
    "ROUTER" => "router", "MIKROTIK" => "router", "SWITCH" => "router",
    "PRINTER" => "printer", "SERVER" => "server", "TABLET" => "tablet",
    "BIOMETRIC" => "biometrics_machine", "BIOMETRICS" => "biometrics_machine"
  }.freeze

  # Router IPs that all belong on the shared MIKROTIK device record.
  ROUTER_IPS = %w[192.168.13.156 192.168.14.155 172.16.242.50 172.16.242.89].freeze

  TITLES = %w[MR MRS MISS MS ENGR ENG DR PASTOR PST CHIEF].freeze
  NAME_FIXES = { "OLA" => "OLAOYE" }.freeze
  NON_PERSON_WORDS = %w[
    OFFICE FINANCE FIN FINNACE ACCT ACCOUNT STORE STOR STORES WAREHOUSE MARKETING MKT
    WORKSHOP PERSONNEL PERSONEL PERSONELL PERONNEL
    FACTORY YALE HEADQUATERS HEADQUARTERS HEAD HARVARD HAVARD VITAL SUMAL
    SYS SYSTEM DESK DESKTOP DESKSTOP LAPTOP ROUTER SWITCH MIKROTIK
    WEIGHBRIDGE WAYBRIDGE WAY BRIDGE BRIDGE
    UTILITY AUTO AUTOMOBILE ERP MIX MIXING RAW MATERIAL PALLET PALLETS
    CLINIC QUALITY AUDIT AUDITOR FEMALE MALE PM OFFICER
    CENTRAL MAIN DESIGNER DESIGN SPARE PART PARTS
    WARE HOUSE Y1 Y2 Y3 Y4 Y5 Y9 STOREKEEPER KEEPER SECOND 2ND 1ST 3RD
    WEREHOUSE
  ].freeze

  DEPT_CODES = {
    "Account Office" => "ACCT", "Account" => "ACCT", "Finance" => "FIN",
    "Personnel Office" => "PO", "Personnel" => "PM", "Personnel Manager" => "PM",
    "Store" => "STORE", "Warehouse" => "WH", "Marketing" => "MKT",
    "UTILITY" => "UTILITY", "Weight Bridge" => "WGTB", "Waybill" => "WAYB",
    "Automobile" => "AUTO", "IT Office" => "IT", "Audit" => "AUDIT",
    "Mixing Section" => "MIX", "Raw Material" => "RM", "Pallet Generation" => "PG",
    "Facilities" => "FAC", "ERP Office" => "ERP", "Clinic" => "CLINIC",
    "Food Safety & Quality" => "FSQ", "Sales" => "SALES"
  }.freeze

  def self.call(entries: SpreadsheetRowParser.parse, dry_run: true)
    new(entries, dry_run: dry_run).call
  end

  def initialize(entries, dry_run:)
    @entries = entries
    @dry_run = dry_run
    @report = Hash.new { |hash, key| hash[key] = [] }
    @report[:dry_run] = dry_run
    # Same person + same branch/dept across different sheet rows resolves
    # to one device, so a dry-run plans it once and a live run links all
    # of that person's IPs to the same record instead of minting dupes.
    @devices_by_identity = {}
  end

  def call
    groups.each do |key, group_entries|
      if @dry_run
        process_group(group_entries, mikrotik: key == "mikrotik")
      else
        ActiveRecord::Base.transaction { process_group(group_entries, mikrotik: key == "mikrotik") }
      end
    end
    summarize
    @report
  end

  private

  # One device per sheet row (data IP + internet IP stay together), except
  # router IPs which share the MIKROTIK group even when they share a row
  # with a workstation IP (e.g. .13.122 + typo .242.89).
  def groups
    router, rest = @entries.partition { |entry| ROUTER_IPS.include?(entry.ip) }
    grouped = rest.group_by(&:row_id)
    grouped["mikrotik"] = router if router.any?
    grouped
  end

  def process_group(group_entries, mikrotik: false)
    live = group_entries.reject(&:free)
    if live.empty?
      @report[:skipped_free] << group_entries.first.row_id
      return
    end

    records = live.map { |entry| [ entry, find_ip(entry) ] }
    missing = records.select { |_, record| record.nil? }.map(&:first)
    missing.each { |entry| @report[:skipped_missing] << "#{entry.ip} (#{entry.row_id})" }
    records = records.reject { |_, record| record.nil? }
    return if records.empty?

    # Bare inventory listings (S/N + IP, no owner/desk text) carry nothing
    # to import: unlinked ones are skipped, linked ones stand as agreed.
    # Router rows are meaningful by construction and skip this gate.
    informative = mikrotik ? live : live.select { |entry| informative?(entry) }
    if informative.empty?
      if records.all? { |_, record| record.device_id.nil? }
        @report[:skipped_blank] << "#{live.first.row_id} (#{live.map(&:ip).join(", ")})"
        return
      end
      records.each { |entry, record| @report[:agreed] << entry.ip }
      return
    end

    device = resolve_device(informative, records, mikrotik: mikrotik)
    return if device.nil?

    records.each { |entry, record| link_ip(entry, record, device) }
    cleanup_lonely_device(device, records)
  end

  def informative?(entry)
    [ entry.device_text, entry.office_text, entry.user_name, entry.description ].any?(&:present?)
  end

  def find_ip(entry)
    IpAddress.where("host(address) = ?", entry.ip).first
  end

  # MAC-first: row MAC -> device by MAC; else the IPs' current device;
  # else find-or-create from sheet text. Never splits a device from its MAC.
  def resolve_device(group_entries, records, mikrotik: false)
    representative = group_entries.find { |entry| !entry.free } || group_entries.first

    mac = group_entries.map(&:mac).compact.first
    if mac
      by_mac = Device.find_by("lower(mac_address) = ?", mac)
      return by_mac if by_mac
    end

    linked = records.map(&:last).map(&:device).compact.uniq
    return linked.first if linked.size == 1

    if linked.size > 1
      @report[:errors] << "#{representative.row_id}: IPs already split across #{linked.map(&:name).join(", ")}; left alone"
      return nil
    end

    return mikrotik_device if mikrotik || group_entries.any? { |entry| ROUTER_IPS.include?(entry.ip) }

    build_device(representative, mac)
  end

  def mikrotik_device
    branch = Branch.find_by(name: "Yale 1")
    department = branch&.departments&.find_by(name: "IT Office")
    unless branch && department
      @report[:errors] << "mikrotik: Yale 1 / IT Office missing; cannot create MIKROTIK device"
      return nil
    end
    device = Device.find_by("lower(name) = ?", "mikrotik")
    return device if device

    device = Device.new(name: "MIKROTIK", department: department,
                        device_type: :router, infrastructure: true,
                        notes: "Estate MikroTik router (spreadsheet import).")
    persist(device, label: "device MIKROTIK")
  end

  def build_device(entry, mac)
    branch = resolve_branch(entry)
    return nil if branch.nil?
    department = resolve_department(entry, branch)
    return nil if department.nil?

    person = extract_person(entry, department)
    # Person + branch + dept defines a device: a second row for the same
    # person merges onto it (reported) instead of minting a "-2" dupe.
    identity = [ branch.id, department.name, person, mac ].join("|")
    if @devices_by_identity.key?(identity)
      device = @devices_by_identity[identity]
      @report[:merged_rows] << "#{device.name} <= #{entry.row_id}"
      return device
    end

    base = device_name(branch, department, person)
    name = unique_device_name(base)
    device = Device.new(
      name: name,
      department: department,
      employee: match_employee(person),
      device_type: device_type_for(entry),
      mac_address: mac,
      location: entry.location.presence || entry.office_text,
      notes: "Imported from #{entry.source} sheet #{entry.sheet}."
    )
    persisted = persist(device, label: "device #{name}")
    @devices_by_identity[identity] = persisted if persisted
    persisted
  end

  def persist(device, label:)
    if @dry_run
      unless device.valid?
        @report[:errors] << "#{label} invalid: #{device.errors.full_messages.to_sentence}"
        return nil
      end
      @report[:planned_devices] << device.name
      return device
    end

    if device.new_record?
      device.save!
      @report[:created_devices] << device.name
    end
    device
  rescue ActiveRecord::RecordInvalid => error
    @report[:errors] << "#{label}: #{error.record.errors.full_messages.to_sentence}"
    nil
  end

  def link_ip(entry, record, device)
    if record.device_id.present? && record.device_id == device.id
      if sheet_agrees_with_device?(entry, device)
        @report[:agreed] << entry.ip
      else
        # Same link, different story: the live link wins, sheet becomes a note.
        @report[:conflicts_kept] << "#{entry.ip}: kept #{device.name}, sheet said #{sheet_summary(entry)}"
        append_note(record, entry)
      end
      fill_mac(entry, device)
      return
    end

    if record.device
      # Row MAC points at another device, but the IP is live-linked
      # elsewhere: the live link wins, loudly.
      @report[:conflicts_kept] << "#{entry.ip}: kept #{record.device.name} (live link), sheet MAC belongs to #{device.name}"
      append_note(record, entry)
      return
    end

    record.device = device
    if @dry_run
      unless record.valid?
        @report[:errors] << "#{entry.ip}: cannot link to #{device.name}: #{record.errors.full_messages.to_sentence}"
        return
      end
      @report[:planned_links] << "#{entry.ip} -> #{device.name}"
      return
    end

    record.save!
    append_note(record, entry)
    @report[:linked] << "#{entry.ip} -> #{device.name}"
    fill_mac(entry, device)
  rescue ActiveRecord::RecordInvalid => error
    @report[:errors] << "#{entry.ip}: #{error.record.errors.full_messages.to_sentence}"
  end

  # Fill a blank device MAC from sheet data; never overwrite a set one.
  def fill_mac(entry, device)
    return if entry.mac.blank?
    if device.mac_address.blank?
      if @dry_run
        @report[:planned_mac_fills] << "#{device.name} <= #{entry.mac}"
      else
        device.update!(mac_address: entry.mac)
        @report[:mac_fills] << "#{device.name} <= #{entry.mac}"
      end
    elsif device.mac_address.downcase != entry.mac.downcase
      @report[:mac_conflicts] << "#{device.name}: DB has #{device.mac_address}, sheet said #{entry.mac}; kept DB"
    end
  end

  # A device created by this run that ended up holding no IPs is noise.
  def cleanup_lonely_device(device, records)
    return if @dry_run || !device.previously_new_record?
    return if records.any? { |_, record| record.device_id == device.id }
    device.destroy!
    @report[:created_devices].delete(device.name)
    @report[:errors] << "#{device.name}: created but no IP could be linked; removed again"
  end

  def append_note(record, entry)
    marker = "Sheet(#{entry.source}/#{entry.sheet}##{entry.row_id.split("#").last}): #{sheet_summary(entry)}"
    return if record.notes.to_s.include?(marker)
    combined = [ record.notes.presence, marker ].compact.join(" | ")
    if @dry_run
      @report[:planned_notes] << "#{entry.ip}: #{marker}"
    else
      record.update!(notes: combined)
    end
  end

  def resolve_branch(entry)
    key = entry.factory.to_s.strip.upcase.gsub(/\s+/, " ")
    key = key.gsub(/\AYALE(\d)/, "YALE \\1")
    # The FACTORY column sometimes holds a longer phrase (YALE 4 C/S,
    # YALE 9 STORE): reduce it to the Yale number when it is not an
    # exact known key.
    if !FACTORY_BRANCHES.key?(key) && (number = key[/\AYALE\s*(\d+)/, 1])
      key = "YALE #{number}"
    end
    if STATUS_FACTORIES.include?(key)
      @report[:status_factory] << "#{entry.row_id}: factory #{entry.factory.inspect} reads as a status note"
      key = ""
    end
    name = FACTORY_BRANCHES[key] || factory_contains_branch(key) || branch_from_location(entry)
    branch = name && Branch.find_by(name: name)
    if branch.nil?
      @report[:unmappable] << "#{entry.row_id}: factory #{entry.factory.inspect} / location #{entry.location.inspect}"
    end
    branch
  end

  STATUS_FACTORIES = %w[PING UNREACHABLE BLACKMAN IN\ USE USED FREE].freeze

  # Last resort for factory text: a branch name hiding inside a longer
  # phrase ("HAVARD PM OFFICE" -> Havard).
  def factory_contains_branch(key)
    return "Havard" if key.include?("HAVARD") || key.include?("HARVARD")
    return "Vital" if key.include?("VITAL")
    return "Sumal" if key.include?("SUMAL") || key.include?("HEAD")
    nil
  end

  # Blackman rows carry Location instead of factory ("Yale 5", "Head office", ...).
  def branch_from_location(entry)
    location = "#{entry.location} #{entry.office_text} #{entry.user_name}".upcase
    return "Yale 1" if location.match?(/YALE\s*1|\bY1[\s-]/)
    return "Yale 2" if location.match?(/YALE\s*2|\bY9\b|\bY2[\s-]/)
    return "Yale 3" if location.match?(/YALE\s*3|\bY3[\s-]/)
    return "Yale 4" if location.match?(/YALE\s*4|\bY4[\s-]/)
    return "Yale 5" if location.match?(/YALE\s*5|\bY5[\s-]/)
    return "Yale 8" if location.match?(/YALE\s*8|\bY8[\s-]/)
    return "Yale 9" if location.match?(/YALE\s*9/)
    return "Yale 10" if location.match?(/YALE\s*10/)
    return "Yale 12" if location.match?(/YALE\s*12/)
    return "Yale 14" if location.match?(/YALE\s*14/)
    return "Havard" if location.match?(/HAVARD|HARVARD/)
    return "Vital" if location.match?(/VITAL/)
    return "Sumal" if location.match?(/HEAD|SUMAL/)
    return "Yale 1" if location.match?(/MIKROTIK/)
    nil
  end

  def resolve_department(entry, branch)
    office = departmental_text(entry)
    name = OFFICE_DEPARTMENTS[office.upcase] ||
      best_department_match(office, branch.departments.map(&:name)) ||
      best_department_match(office, Department.distinct.pluck(:name)) ||
      fallback_department(entry, branch, office)
    return nil if name.nil?
    department = branch.departments.find_by("lower(name) = ?", name.downcase)
    return department if department
    create_department(branch, name, entry)
  end

  # Desk text minus the person: the office part ("ACCT OFFICE MR KENY"
  # with KENY removed). Device-model words ("ALL IN ONE") are not
  # departments and stay out.
  def departmental_text(entry)
    text = "#{entry.office_text} #{entry.description}"
    person = extract_person(entry, nil)
    text = text.gsub(/#{Regexp.escape(person)}/i, "") if person
    cleaned = text.upcase.split(/[^A-Z0-9&]+/).reject { |token| token.length < 3 || TITLES.include?(token) }
    OFFICE_DEPARTMENTS.each_key do |key|
      return key if cleaned.join(" ").include?(key)
    end
    cleaned.reject { |token| NON_PERSON_WORDS.include?(token) }.first(3).join(" ").presence || ""
  end

  # Token overlap with stemming (AUDIT matches AUDITOR, STORE matches
  # STORES): returns the canonical existing name, so new departments reuse
  # estate vocabulary instead of inventing near-dupes.
  def best_department_match(office, names)
    tokens = office.upcase.split(/[^A-Z0-9]+/).select { |token| token.length >= 3 }
    return nil if tokens.empty?
    scored = names.filter_map do |name|
      overlap = name.upcase.split(/[^A-Z0-9]+/).count do |word|
        tokens.any? { |token| dept_token_match?(token, word) }
      end
      [ name, overlap ] if overlap.positive?
    end
    scored.max_by(&:last)&.first
  end

  def dept_token_match?(token, word)
    return false if word.length < 4
    return true if token == word
    common = token.chars.zip(word.chars).take_while { |a, b| a == b }.size
    common >= 5
  end

  # Nothing recognizable: park in branch Facilities and flag the row for
  # review instead of inventing a junk department.
  def fallback_department(entry, branch, office)
    facilities = branch.departments.find_by("lower(name) = ?", "facilities")
    facilities ||= create_department(branch, "Facilities", entry)
    if facilities
      raw = "#{entry.office_text} #{entry.device_text}".strip.presence || "(no office text)"
      @report[:dept_fallback] << "#{entry.row_id}: #{raw} -> #{branch.name} / Facilities"
      return facilities.name
    end
    nil
  end

  def create_department(branch, name, entry)
    department = branch.departments.build(name: name)
    if @dry_run
      unless department.valid?
        @report[:errors] << "#{entry.row_id}: department #{branch.name} / #{name} invalid"
        return nil
      end
      @report[:planned_departments] << "#{branch.name} / #{name}"
      return department
    end
    department.save!
    @report[:created_departments] << "#{branch.name} / #{name}"
    department
  rescue ActiveRecord::RecordInvalid => error
    @report[:errors] << "#{entry.row_id}: #{error.record.errors.full_messages.to_sentence}"
    nil
  end

  def extract_person(entry, department)
    raw = "#{entry.office_text} #{entry.user_name}"
    tokens = raw.upcase.split(/[^A-Z0-9]+/)
      .reject { |token| token.length < 3 || TITLES.include?(token) || token.match?(/\A\d+(ST|ND|RD|TH)\z/) }
    tokens = tokens.map { |token| NAME_FIXES.fetch(token, token) }
    dept_words = department&.name&.upcase&.split(/[^A-Z0-9]+/) || []
    candidates = tokens - NON_PERSON_WORDS - dept_words - OFFICE_DEPARTMENTS.keys.flat_map { |key| key.split }
    candidates.last
  end

  def device_name(branch, department, person)
    prefix = branch.name.sub(/\AYale (\d+)\z/i, "Y\\1").upcase
    code = DEPT_CODES.fetch(department.name, department.name.upcase.gsub(/[^A-Z]/, "").first(4))
    [ prefix, code, person || "SHARED" ].join("-")
  end

  # Loose token overlap between sheet text and the linked device: decides
  # whether an existing link "agrees" with the sheet or is a stale-sheet
  # conflict (kept, but noted).
  GENERIC_WORDS = %w[
    YALE HEAD OFFICE DESKTOP DESKSTOP LAPTOP FINANCE FIN ACCT ACCOUNT
    ENGR ENG SYSTEM SYS WITH FROM STORE STOR WAREHOUSE MARKETING MKT
    PERSONNEL PERSONEL PERSONAL WORKSHOP ROUTER SWITCH MIKROTIK UTILITY
    ERP MIX MIXING RAW MATERIAL PALLET CLINIC AUDIT SALES ALL ONE
  ].freeze

  def sheet_agrees_with_device?(entry, device)
    sheet_tokens = "#{entry.factory} #{entry.device_text} #{entry.office_text} #{entry.user_name}"
      .upcase.split(/[^A-Z0-9]+/).select { |token| token.length >= 4 } - GENERIC_WORDS
    # A bare inventory listing (S/N + IP, no owner text) says nothing to
    # disagree with: the live link stands silently, without a junk note.
    return true if sheet_tokens.empty?
    haystack = "#{device.name} #{device.notes}".upcase
    sheet_tokens.any? { |token| haystack.include?(token) }
  end

  def unique_device_name(base)
    name, suffix = base, 1
    while Device.where("lower(name) = ?", name.downcase).exists?
      suffix += 1
      name = "#{base}-#{suffix}"
    end
    name
  end

  def match_employee(person)
    return nil if person.blank?
    matches = Employee.where("upper(first_name) = ? OR upper(last_name) = ?", person, person)
    matches.one? ? matches.first : nil
  end

  def device_type_for(entry)
    text = "#{entry.device_text} #{entry.description}".upcase
    DEVICE_TYPES.each { |key, type| return type if text.include?(key) }
    "desktop"
  end

  def sheet_summary(entry)
    [ entry.factory, entry.device_text, entry.office_text || entry.user_name ].compact.join(" / ")
  end

  def summarize
    @report[:linked_count] = @report[:linked].size
    @report[:planned_links_count] = @report[:planned_links].size
  end
end
