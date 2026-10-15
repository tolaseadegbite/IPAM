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
