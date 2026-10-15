require "test_helper"

class SpreadsheetImportServiceTest < ActiveSupport::TestCase
  Entry = SpreadsheetRowParser::Entry

  setup do
    @branch = Branch.create!(name: "Yale 1")
    @department = @branch.departments.create!(name: "Account Office")
    Subnet.create!(name: "Corporate Data (.13)", network_address: "192.168.13.0/24", gateway: "192.168.13.1")
    Subnet.create!(name: "Internet IP (.16)", network_address: "172.16.242.0/24", gateway: "172.16.242.1")
    @existing_device = Device.create!(name: "Y1-OLD-PC", department: @department, device_type: :desktop)
    linked = IpAddress.where("host(address) = ?", "192.168.13.30").first
    linked.update!(device: @existing_device)
  end

  test "dry-run changes nothing" do
    assert_no_difference [ "Device.count", "Department.count" ] do
      report = SpreadsheetImportService.call(entries: import_entries, dry_run: true)
      assert_equal 2, report[:planned_links_count]
      assert_equal "Y1-ACCT-KENY", report[:planned_devices].first
      assert report[:conflicts_kept].any? { |line| line.include?("192.168.13.30") }
    end
    assert_nil IpAddress.where("host(address) = ?", "192.168.13.10").first.device
  end

  test "live run links workstation IPs to one new device and keeps conflicts" do
    report = SpreadsheetImportService.call(entries: import_entries, dry_run: false)

    device = Device.find_by(name: "Y1-ACCT-KENY")
    assert_not_nil device
    assert_equal "ac:cd:ef:12:34:56", device.mac_address
    assert_equal %w[172.16.242.99 192.168.13.10],
                 device.ip_addresses.map { |ip| ip.address.to_s }.sort
    assert report[:linked].any? { |line| line.start_with?("192.168.13.10") }

    kept = IpAddress.where("host(address) = ?", "192.168.13.30").first
    assert_equal @existing_device.id, kept.device_id
    assert_includes kept.notes, "Sheet("
  end

  test "live run is idempotent" do
    SpreadsheetImportService.call(entries: import_entries, dry_run: false)
    second = nil
    assert_no_difference [ "Device.count", "Department.count" ] do
      second = SpreadsheetImportService.call(entries: import_entries, dry_run: false)
    end
    assert_empty second[:errors]
    assert_equal 2, second[:agreed].size
    kept = IpAddress.where("host(address) = ?", "192.168.13.30").first
    assert_equal 1, kept.notes.scan("Sheet(").size
  end

  test "fills a blank device MAC but never overwrites a set one" do
    blank = Device.create!(name: "Y1-NOMAC-PC", department: @department, device_type: :desktop)
    IpAddress.where("host(address) = ?", "192.168.13.20").first.update!(device: blank)

    fill = entry_for(ip: "192.168.13.20", factory: "YALE 1",
                     device_text: "LAPTOP", office_text: "ACCT OFFICE MR KENY",
                     mac: "aa:bb:cc:dd:ee:ff")
    report = SpreadsheetImportService.call(entries: [ fill ], dry_run: false)
    assert_equal [ "Y1-NOMAC-PC <= aa:bb:cc:dd:ee:ff" ], report[:mac_fills]
    assert_equal "aa:bb:cc:dd:ee:ff", blank.reload.mac_address

    clash = entry_for(ip: "192.168.13.20", factory: "YALE 1",
                      device_text: "LAPTOP", office_text: "ACCT OFFICE MR KENY",
                      mac: "11:22:33:44:55:66")
    clash_report = SpreadsheetImportService.call(entries: [ clash ], dry_run: false)
    assert_equal 1, clash_report[:mac_conflicts].size
    assert_equal "aa:bb:cc:dd:ee:ff", blank.reload.mac_address
  end

  test "matches a row MAC to its device even for a different IP" do
    known = Device.create!(name: "Y1-CAM-1", department: @department,
                           device_type: :desktop, mac_address: "aa:bb:cc:dd:ee:ff")
    row = entry_for(ip: "172.16.242.20", factory: nil, device_text: nil,
                    office_text: "Yale 5", row: "cam", mac: "AA-BB-CC-DD-EE-FF")
    assert_no_difference "Device.count" do
      SpreadsheetImportService.call(entries: [ row ], dry_run: false)
    end
    assert_equal known.id, IpAddress.where("host(address) = ?", "172.16.242.20").first.device_id
  end

  test "mac-bearing rows claim duplicate sheet IPs first" do
    plain = entry_for(ip: "172.16.242.99", factory: "YALE 1", device_text: "DESKTOP",
                      office_text: "STORE MR ALPHA", row: "plain")
    with_mac = entry_for(ip: "172.16.242.99", factory: "YALE 1", device_text: "DESKTOP",
                         office_text: "STORE MR BETA", row: "macrow", mac: "de:ad:be:ef:00:01")
    report = SpreadsheetImportService.call(entries: [ plain, with_mac ], dry_run: true)
    assert_equal 1, report[:planned_links_count]
    assert_match(/BETA/, report[:planned_links].first)
    assert_equal 1, report[:planned_conflicts].size
  end

  test "creates titled employees and never for guarded names" do
    keny = entry_for(ip: "192.168.13.10", factory: "YALE 1", device_text: "DESKTOP",
                     office_text: "ACCT OFFICE MR KENY", row: "k1")
    report = SpreadsheetImportService.call(entries: [ keny ], dry_run: true)
    assert report[:planned_employees].any? { |line| line.start_with?("Mr Keny (Yale 1 / Account Office)") }

    guarded = entry_for(ip: "192.168.13.20", factory: "YALE 1", device_text: "DESKTOP",
                        office_text: "ENGR VERGHESE SYS", row: "g1")
    guarded_report = SpreadsheetImportService.call(entries: [ guarded ], dry_run: true)
    assert_empty guarded_report[:planned_employees]
    assert_equal [ "Y1-FAC-VARGHESE" ], guarded_report[:planned_devices]
  end

  test "fills blank owners from device-name surnames on agreed rows" do
    morris = Employee.create!(first_name: "Engr", last_name: "Morris",
                              department: @department, status: :active)
    device = Device.create!(name: "Y9-FACT-ENGR-MORRIS-PC", department: @department,
                            device_type: :laptop)
    IpAddress.where("host(address) = ?", "192.168.13.40").first.update!(device: device)
    row = entry_for(ip: "192.168.13.40", factory: "YALE 2", device_text: "LAPTOP",
                    office_text: "Y9 ENGR OFFICE", row: "m1")
    report = SpreadsheetImportService.call(entries: [ row ], dry_run: true)
    assert_equal [ "Y9-FACT-ENGR-MORRIS-PC <= Engr Morris" ], report[:planned_owner_fills]
  end

  test "matches person tokens inside display-style employee names" do
    # Estate convention stores display names whole in first_name.
    Employee.new(first_name: "Engr Morris", last_name: "", department: @department, status: :active)
            .save(validate: false)
    Branch.create!(name: "Yale 9")
    row = entry_for(ip: "192.168.13.70", factory: "YALE 9", device_text: "DESKTOP",
                    office_text: "EGNR MORRIS WORKSHOP", row: "dm")
    report = SpreadsheetImportService.call(entries: [ row ], dry_run: true)
    assert_empty report[:planned_employees]
    assert_equal [ "Y9-FAC-MORRIS" ], report[:planned_devices]
  end

  test "maps C/S rows to Central Store and AIO to all-in-one" do
    yale4 = Branch.create!(name: "Yale 4")
    row = entry_for(ip: "192.168.13.50", factory: "YALE 4 C/S", device_text: "IN USE",
                    office_text: "C/S AIO RECORDS", row: "cs1")
    report = SpreadsheetImportService.call(entries: [ row ], dry_run: true)
    assert_equal [ "Yale 4 / Central Store" ], report[:planned_departments]
    assert_equal [ "Y4-CST-SHARED" ], report[:planned_devices]
    assert_equal "all_in_one", SpreadsheetImportService.new([], dry_run: true).send(:device_type_for, row)
  end

  test "maps paolo rows to Yale 4 Chief Engineer with titled owner" do
    yale4 = Branch.create!(name: "Yale 4")
    row = entry_for(ip: "192.168.13.60", factory: nil, device_text: nil,
                    office_text: "paolo office", row: "p1")
    report = SpreadsheetImportService.call(entries: [ row ], dry_run: true)
    assert_equal [ "Yale 4 / Chief Engineer" ], report[:planned_departments]
    assert_equal [ "Y4-CHIEF-PAOLO" ], report[:planned_devices]
  end

  private

  def import_entries
    [
      entry_for(ip: "192.168.13.10", factory: "YALE 1", device_text: "DESKTOP",
                office_text: "ACCT OFFICE MR KENY", row: "r1"),
      entry_for(ip: "172.16.242.99", factory: "YALE 1", device_text: "DESKTOP",
                office_text: "ACCT OFFICE MR KENY", row: "r1", mac: "AC-CD-EF-12-34-56"),
      entry_for(ip: "192.168.13.30", factory: "YALE 1", device_text: "DESKTOP",
                office_text: "ENGR OFFICE PRAJU", row: "r2"),
      entry_for(ip: "192.168.13.40", factory: "YALE 1", device_text: "DESKTOP",
                office_text: "STORE", row: "r3", free: true),
      entry_for(ip: "10.9.9.9", factory: "YALE 1", device_text: "DESKTOP",
                office_text: "STORE", row: "r4")
    ]
  end

  def entry_for(ip:, factory:, device_text:, office_text:, row: "r9", mac: nil, free: false)
    Entry.new(source: "test", sheet: "TEST", row_id: "test##{row}", ip: ip,
              mac: mac && mac.downcase.tr("-", ":"), factory: factory,
              device_text: device_text, office_text: office_text,
              user_name: nil, location: nil, description: nil, free: free)
  end
end
