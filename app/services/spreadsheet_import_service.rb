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
    "Y2 ENGR RAFU" => "Yale 2", "IMPORT" => "Sumal"
  }.freeze

  # Office/desk text -> Department name within the branch (typos included:
  # the sheets write FINNACE, PERONNEL, DESKSTOP ...). Matched longest-key
  # first against the raw text, so multi-word keys win over fragments.
  OFFICE_DEPARTMENTS = {
    "ACCT OFFICE" => "Account Office", "ACCOUNT OFFICE" => "Account Office",
    "ACCOUNT" => "Account", "FINANCE OFFICE" => "Finance", "FINANCE" => "Finance",
    "FINNACE" => "Finance", "FINNACE OFFICE" => "Finance",
    "PERSONNEL OFFICE" => "Personnel Office", "PERSONNEL" => "Personnel",
    "PERONNEL" => "Personnel Office", "PERSONEL" => "Personnel",
    "STORE" => "Store", "MAIN STORE" => "Store",
    "CENTRAL STORE" => "Central Store",
    "WAREHOUSE" => "Warehouse",
    "MARKETING" => "Marketing", "WAYBILL" => "Waybill",
    "WEIGHBRIDGE" => "Weight Bridge", "WAY BRIDGE" => "Weight Bridge",
    "UTILITY OFFICE" => "UTILITY", "UTILITY" => "UTILITY",
    "AUTOMOBILE" => "Automobile", "ERP OFFICE" => "ERP Office",
    "MIXING SECT" => "Mixing Section", "MIXING" => "Mixing Section",
    "RAW MATERIAL" => "Raw Material", "PALLET GENERATION" => "Pallet Generation",
    "AUDIT" => "Audit", "AUDITOR" => "Audit", "CLINIC" => "Clinic", "SALES" => "Sales",
    "SERVER ROOM" => "Server Room", "SERVER" => "Server Room",
    "PAOLO" => "Chief Engineer", "IMPORT" => "Import", "MD OFFICE" => "MD Office"
  }.freeze

  DEVICE_TYPES = {
    "DESKTOP" => "desktop", "DESKSTOP" => "desktop",
    "LAPTOP" => "laptop", "ALL IN ONE" => "all_in_one", "ALL-IN-ONE" => "all_in_one",
    "AIO" => "all_in_one",
    "ROUTER" => "router", "MIKROTIK" => "router", "SWITCH" => "router",
    "PRINTER" => "printer", "SERVER" => "server", "TABLET" => "tablet",
    "BIOMETRIC" => "biometrics_machine", "BIOMETRICS" => "biometrics_machine"
  }.freeze

  # Router IPs that all belong on the shared MIKROTIK device record.
  ROUTER_IPS = %w[192.168.13.156 192.168.14.155 172.16.242.50 172.16.242.89].freeze

  TITLES = %w[MR MRS MISS MS ENGR ENG EGNR DR PASTOR PST CHIEF].freeze
  # Title variants collapse to one spelling so Eng/Engr rows share a person.
  TITLE_NORMALIZE = {
    "MR" => "Mr", "MRS" => "Mrs", "MISS" => "Miss", "MS" => "Ms",
    "ENGR" => "Engr", "ENG" => "Engr", "EGNR" => "Engr",
    "DR" => "Dr", "PASTOR" => "Pastor", "PST" => "Pastor", "CHIEF" => "Chief"
  }.freeze
  NAME_FIXES = { "OLA" => "OLAOYE", "VERGHESE" => "VARGHESE" }.freeze
  # Person tokens that must never gain an employee record or ownership:
  # Varghese owns exactly Y1-Engr-Varghese-PC; other rows naming his
  # office belong to his office-mates (unknown) and stay ownerless.
  OWNER_NEVER_LINK = %w[VARGHESE].freeze
  # Adjudicated person placements: [branch, department] for people the
  # sheets never locate (all confirmed).
  PERSON_PLACEMENT = {
    "SUDARSAN" => [ "Sumal", "MD Office" ],
    "AKINTAYO" => [ "Sumal", "Account Office" ],
    "BLACKMAN" => [ "Yale 1", "IT Office" ],
    "PAOLO" => [ "Yale 4", "Chief Engineer" ]
  }.freeze
  # Branches the import is allowed to create (all confirmed).
  NEW_BRANCHES = %w[Houses Powerplant].freeze
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
    WEREHOUSE WHAREHOUSE RECORDS RECORD PURCHASE RADIO LINK KPMG CON BIO
    AIO CAMERA CAMERAS ENGINEER POWERPLANT IMPORTED
    SIDE OFF MACHINE GRAB PRINTING REQUISITION FIRE ALARM LNG PLANT
    WIFI APP GUEST NEW SMALL TALLY TECHN TECHNICIAN INTERNAL
    CONFERENCE DATABASE INTERNET QUARTERS HOUSE HOME
    BREAD METRICS GRAPHICS MANAGER EXT GEN REGULATORY WAFER
    GENERATION RECEIVING GENERAL RECEIEVING OLD
  ].freeze

  DEPT_CODES = {
    "Account Office" => "ACCT", "Account" => "ACCT", "Finance" => "FIN",
    "Personnel Office" => "PO", "Personnel" => "PM", "Personnel Manager" => "PM",
    "Store" => "STORE", "Warehouse" => "WH", "Marketing" => "MKT",
    "UTILITY" => "UTILITY", "Weight Bridge" => "WGTB", "Waybill" => "WAYB",
    "Automobile" => "AUTO", "IT Office" => "IT", "Audit" => "AUDIT",
    "Mixing Section" => "MIX", "Raw Material" => "RM", "Pallet Generation" => "PG",
    "Facilities" => "FAC", "ERP Office" => "ERP", "Clinic" => "CLINIC",
    "Food Safety & Quality" => "FSQ", "Sales" => "SALES",
    "Chief Engineer" => "CHIEF", "Central Store" => "CST", "Server Room" => "SRV",
    "Import" => "IMP", "MD Office" => "MD", "CCTV" => "CCTV"
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
    # Dry-run mirror of live links: the first group to claim an IP wins,
    # later groups plan a conflict (same as the live run would record).
    @planned_device_by_ip = {}
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
  # with a workstation IP (e.g. .13.122 + typo .242.89). Groups carrying a
  # MAC run first so that, on duplicate sheet IPs, the MAC row claims the
  # address and the MAC-less row becomes a notes-only conflict.
  def groups
    router, rest = @entries.partition { |entry| ROUTER_IPS.include?(entry.ip) }
    grouped = rest.group_by(&:row_id)
    grouped["mikrotik"] = router if router.any?
    mac_groups, plain = grouped.partition { |key, group| key != "mikrotik" && group.any?(&:mac) }
    (mac_groups + plain).to_h
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
    disposition = explicit_disposition(entry)
    if disposition == :skip
      @report[:skipped_cameras] << "#{entry.row_id} (#{entry.ip})"
      return nil
    end

    branch = disposition ? find_or_create_branch(disposition.first, entry) : resolve_branch(entry)
    return nil if branch.nil?
    department = resolve_department(entry, branch, forced: disposition&.last)
    return nil if department.nil?

    person = extract_person(entry, department)

    # A distinctive person token matching one existing device in the
    # branch reuses it (BLACKMAN -> Y1-IT-Blackman-PC) instead of minting
    # a lookalike. Guarded names (VARGHESE) never reuse: ownership there
    # is settled and stays untouched.
    if person && person.length >= 6 && !OWNER_NEVER_LINK.include?(person)
      namesake = Device.where(department_id: branch.departments.select(:id))
                       .where("name ILIKE ?", "%#{person}%")
      if namesake.one?
        @report[:reused_devices] << "#{namesake.first.name} <= #{entry.row_id}"
        return namesake.first
      end
    end
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
      employee: resolve_employee(person, department, entry),
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
      fill_owner(entry, device, from_sheet: true)
      return
    end

    if record.device
      # Row MAC points at another device, but the IP is live-linked
      # elsewhere: the live link wins, loudly.
      @report[:conflicts_kept] << "#{entry.ip}: kept #{record.device.name} (live link), sheet MAC belongs to #{device.name}"
      append_note(record, entry)
      fill_owner(entry, record.device, from_sheet: false)
      return
    end

    record.device = device
    if @dry_run
      unless record.valid?
        @report[:errors] << "#{entry.ip}: cannot link to #{device.name}: #{record.errors.full_messages.to_sentence}"
        return
      end
      if @planned_device_by_ip.key?(entry.ip) && @planned_device_by_ip[entry.ip] != device.name
        @report[:planned_conflicts] << "#{entry.ip}: #{@planned_device_by_ip[entry.ip]} first, then #{device.name}"
        return
      end
      @planned_device_by_ip[entry.ip] = device.name
      @report[:planned_links] << "#{entry.ip} -> #{device.name}"
      fill_owner(entry, device, from_sheet: true)
      return
    end

    record.save!
    append_note(record, entry)
    @report[:linked] << "#{entry.ip} -> #{device.name}"
    fill_mac(entry, device)
    fill_owner(entry, device, from_sheet: true)
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
    # Bucket-3 rule (confirmed): an informative row with no locatable
    # factory belongs to Sumal.
    name ||= "Sumal" if entry.factory.blank? && informative?(entry)
    branch = name && Branch.find_by(name: name)
    if branch.nil?
      @report[:unmappable] << "#{entry.row_id}: factory #{entry.factory.inspect} / location #{entry.location.inspect}"
    end
    branch
  end

  # Adjudicated row dispositions (all confirmed): :skip drops the row,
  # [branch, department] forces placement.
  def explicit_disposition(entry)
    text = "#{entry.user_name} #{entry.description}".upcase
    return :skip if text.match?(/CAMERA/)
    location = "#{entry.location} #{entry.office_text} #{entry.user_name}".upcase
    return [ "Powerplant", "CCTV" ] if location.match?(/POWERPLANT/)
    return [ "Houses", "Facilities" ] if location.match?(/QUARTERS|\bHOUSE\b|\bHOME\b/)
    person = extract_person(entry, nil)
    return PERSON_PLACEMENT[person] if person && PERSON_PLACEMENT.key?(person)
    nil
  end

  def find_or_create_branch(name, entry)
    branch = Branch.find_by(name: name)
    return branch if branch
    unless NEW_BRANCHES.include?(name)
      @report[:unmappable] << "#{entry.row_id}: branch #{name} does not exist and is not approved for creation"
      return nil
    end
    branch = Branch.new(name: name)
    if @dry_run
      unless branch.valid?
        @report[:errors] << "#{entry.row_id}: branch #{name} invalid"
        return nil
      end
      @report[:planned_branches] << name
      return branch
    end
    branch.save!
    @report[:created_branches] << name
    branch
  rescue ActiveRecord::RecordInvalid => error
    @report[:errors] << "#{entry.row_id}: #{error.record.errors.full_messages.to_sentence}"
    nil
  end

  STATUS_FACTORIES = %w[PING UNREACHABLE IN\ USE USED FREE].freeze

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
    return "Yale 4" if location.match?(/CENTRAL STORE|C\/S/)
    nil
  end

  def resolve_department(entry, branch, forced: nil)
    return find_or_create_named(branch, forced, entry) if forced
    office = departmental_text(entry)
    name = OFFICE_DEPARTMENTS[office.upcase] ||
      best_department_match(office, branch.departments.map(&:name)) ||
      best_department_match(office, Department.distinct.pluck(:name)) ||
      fallback_department(entry, branch, office)
    return nil if name.nil?
    find_or_create_named(branch, name, entry)
  end

  def find_or_create_named(branch, name, entry)
    department = branch.departments.find_by("lower(name) = ?", name.downcase)
    return department if department
    create_department(branch, name, entry)
  end

  # Desk text, longest key first against the raw text ("ACCT OFFICE MR
  # KENY" hits ACCT OFFICE, not a fragment). Device-model words
  # ("ALL IN ONE") are not departments and stay out; the person is
  # removed before fuzzy matching so names never become departments.
  def departmental_text(entry)
    raw = "#{entry.office_text} #{entry.description} #{entry.user_name}".upcase
    raw = raw.gsub("C/S", "CENTRAL STORE")
    OFFICE_DEPARTMENTS.keys.sort_by(&:length).reverse.each do |key|
      return key if raw.include?(key)
    end
    return "STORE" if raw.match?(/\bST\b/)
    person = extract_person(entry, nil)
    text = person ? raw.gsub(/#{Regexp.escape(person)}/, "") : raw
    cleaned = text.split(/[^A-Z0-9&]+/).reject { |token| token.length < 3 || TITLES.include?(token) }
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
      .reject { |token| token.length < 3 || TITLES.include?(token) || token.match?(/\A\d+(ST|ND|RD|TH)\z/) || token.match?(/\d/) || token.include?("WIFI") }
    tokens = tokens.map { |token| NAME_FIXES.fetch(token, token) }
    dept_words = department&.name&.upcase&.split(/[^A-Z0-9]+/) || []
    key_words = OFFICE_DEPARTMENTS.keys.flat_map { |key| key.split } - PERSON_WORDS
    candidates = tokens.reject { |token| typo_of_known?(token) } - NON_PERSON_WORDS - dept_words - key_words
    # Names lead, desk words trail ("sunil narketing laptop" -> SUNIL).
    candidates.first
  end

  # Near-miss spellings of known non-person words (AUTOMOBLIE,
  # NARKETING, GENRATION): typos, not people.
  def typo_of_known?(token)
    return false if token.length < 4
    limit = token.length >= 6 ? 2 : 1
    NON_PERSON_WORDS.any? do |word|
      next false if word.length < 4 || (token.length - word.length).abs > limit
      damerau(token, word) <= limit
    end
  end

  def damerau(first, second)
    first, second = first.chars, second.chars
    previous = (0..second.size).to_a
    first.each_with_index do |char1, i|
      current = [ i + 1 ]
      second.each_with_index do |char2, j|
        cost = char1 == char2 ? 0 : 1
        current << [ previous[j + 1] + 1, current[j] + 1, previous[j] + cost ].min
      end
      previous = current
    end
    previous.last
  end

  # Department keys that are also person names (PAOLO's office is the
  # Chief Engineer dept, but PAOLO himself is the person).
  PERSON_WORDS = %w[PAOLO].freeze

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
    exact = Employee.where("upper(first_name) = ? OR upper(last_name) = ?", person, person)
    return exact.first if exact.one?
    return nil if exact.any?
    # Estate convention stores display names in first_name ("Engr Morris",
    # "Weight Bridge engineer"): match the person token as a whole word.
    worded = employees_cached.select do |employee|
      employee.full_name.upcase.split(/[^A-Z0-9]+/).include?(person)
    end.uniq(&:id)
    if worded.size > 1
      @report[:ambiguous_owner] << "#{person}: #{worded.map(&:full_name).join(", ")}"
      return nil
    end
    worded.first
  end

  def employees_cached
    @employees_cached ||= Employee.includes(:department).to_a
  end

  # Title as first name, person token as last ("Mr"/"Odunayo"). Guarded
  # names never gain records. Two bare tokens read as first + last
  # ("alonge dapo"); a lone token doubles up (presence demands it).
  def resolve_employee(person, department, entry)
    return nil if person.blank? || OWNER_NEVER_LINK.include?(person)
    found = match_employee(person)
    return found if found
    title = extract_title(entry)
    if title
      normalized_title = TITLE_NORMALIZE.fetch(title, title.titleize)
      first_name, last_name = [ normalized_title, person.titleize ]
    else
      pair = bare_name_pair(entry)
      first_name, last_name = pair ? pair : [ person.titleize, person.titleize ]
    end
    employee = Employee.new(first_name: first_name, last_name: last_name,
                            department: department, status: :active)
    if @dry_run
      unless employee.valid?
        @report[:errors] << "#{entry.row_id}: employee #{first_name} #{last_name} invalid: #{employee.errors.full_messages.to_sentence}"
        return nil
      end
      @report[:planned_employees] << "#{first_name} #{last_name} (#{department.branch.name} / #{department.name})"
      return employee
    end
    employee.save!
    @report[:created_employees] << "#{first_name} #{last_name} (#{department.branch.name} / #{department.name})"
    employee
  rescue ActiveRecord::RecordInvalid => error
    @report[:errors] << "#{entry.row_id}: #{error.record.errors.full_messages.to_sentence}"
    nil
  end

  def extract_title(entry)
    tokens = "#{entry.office_text} #{entry.user_name}".upcase.split(/[^A-Z0-9]+/)
    (tokens & TITLES).first
  end

  # Two surviving person-words and no title: first + last name.
  def bare_name_pair(entry)
    raw = "#{entry.office_text} #{entry.user_name}"
    tokens = raw.upcase.split(/[^A-Z0-9]+/)
      .reject { |token| token.length < 3 || TITLES.include?(token) || token.match?(/\d/) }
    tokens = tokens.map { |token| NAME_FIXES.fetch(token, token) }
    pair = (tokens - NON_PERSON_WORDS).reject { |token| typo_of_known?(token) }
    pair.size == 2 ? [ pair.first.titleize, pair.last.titleize ] : nil
  end

  # Fill a blank owner where sheet and DB concur (agreed rows): from the
  # sheet person, else from a surname in the device name. Never clears or
  # replaces a set owner; shared infrastructure stays ownerless by design.
  def fill_owner(entry, device, from_sheet:)
    return if device.employee_id.present? || device.infrastructure?
    person = from_sheet ? extract_person(entry, device.department) : nil
    employee = resolve_employee(person, device.department, entry) if person
    employee ||= match_employee_from_surname(device)
    return if employee.nil?
    if @dry_run
      @report[:planned_owner_fills] << "#{device.name} <= #{employee.first_name} #{employee.last_name}"
      return
    end
    device.update!(employee: employee)
    @report[:owner_fills] << "#{device.name} <= #{employee.first_name} #{employee.last_name}"
  end

  def match_employee_from_surname(device)
    stopwords = %w[Y Y1 Y2 Y3 Y4 Y5 Y8 Y9 SUMAL VITAL HAVARD PC LAPTOP DESKTOP AIO ALL ONE IT PO WH FAC STORE MKT FIN ACCT ENGR ENG MR]
    tokens = device.name.upcase.split(/[^A-Z0-9]+/).reject { |token| token.length < 4 || stopwords.include?(token) }
    candidates = tokens.filter_map do |token|
      match = Employee.where("upper(first_name) = ? OR upper(last_name) = ?", token, token)
      match.one? ? match.first : nil
    end.uniq
    candidates.one? ? candidates.first : nil
  end

  def device_type_for(entry)
    text = "#{entry.device_text} #{entry.office_text} #{entry.description}".upcase
    DEVICE_TYPES.each { |key, type| return type if text.include?(key) }
    "desktop"
  end

  def sheet_summary(entry)
    [ entry.factory, entry.device_text, entry.office_text || entry.user_name ].compact.join(" / ")
  end

  def summarize
    @report.each_key do |key|
      @report[key] = @report[key].uniq if @report[key].is_a?(Array)
    end
    @report[:linked_count] = @report[:linked].size
    @report[:planned_links_count] = @report[:planned_links].size
  end
end
