require "test_helper"

class NatToolsFixesTest < ActiveSupport::TestCase
  test "find_free_ips reports unknown subnet instead of raising" do
    result = FindFreeIps.new.execute(subnet_id: -1)

    assert_match(/not found/i, result)
  end

  test "find_free_ips returns free addresses" do
    subnet = subnets(:one)
    IpAddress.create!(subnet: subnet, address: "10.0.1.50", status: :available,
                      reachability_status: :unknown)

    result = FindFreeIps.new.execute(subnet_id: subnet.id, count: 5)

    assert_equal [ "10.0.1.50" ], result.map { |r| r[:address] }
  end

  test "find_ip_by_mac accepts dash-separated input" do
    result = FindIpByMac.new.execute(mac_address: "00-11-22-33-44-01")

    assert_equal "Device One", result[:name]
  end

  test "find_ip_by_mac suggests same-vendor devices on near miss" do
    result = FindIpByMac.new.execute(mac_address: "00:11:22:33:44:99")

    assert_match(/did you mean/i, result)
    assert_match(/Device One/, result)
  end

  test "delete_employee refuses first-name-only input" do
    assert_no_difference "Employee.count" do
      result = DeleteEmployee.new.execute(name: "MyString")

      assert_match(/full name/i, result)
    end
  end

  test "delete_employee refuses ambiguous full names" do
    # Fixtures hold two employees named "MyString MyString".
    assert_no_difference "Employee.count" do
      result = DeleteEmployee.new.execute(name: "MyString MyString")

      assert_match(/multiple employees/i, result)
    end
  end

  test "create_device refuses ambiguous first names without creating" do
    assert_no_difference "Device.count" do
      result = CreateDevice.new.execute(
        name: "New Box", device_type: "desktop", department_name: "Engineering",
        employee_name: "MyString"
      )

      assert_match(/multiple employees/i, result)
    end
  end

  test "bulk_create_devices errors only when a new department needs a branch" do
    ok = BulkCreateDevices.new.execute(records_json: [
      { name: "Bulk One", device_type: "desktop", department_name: "Engineering" }
    ].to_json)

    assert_match(/1 succeeded/, ok)

    missing = BulkCreateDevices.new.execute(records_json: [
      { name: "Bulk Two", device_type: "desktop", department_name: "No Such Dept" }
    ].to_json)

    assert_match(/branch_name/i, missing)
    assert_match(/0 succeeded/, missing)
  end

  test "device breakdown filters case-insensitively" do
    exact = GetDeviceBreakdown.new.execute(department: "Engineering")
    lower = GetDeviceBreakdown.new.execute(department: "engineering")
    branch = GetDeviceBreakdown.new.execute(branch: "headquarters")

    assert_equal exact[:total_devices], lower[:total_devices]
    assert_operator lower[:total_devices], :>, 0
    assert_operator branch[:total_devices], :>, 0
  end

  test "branch lookup returns departments, devices and ips" do
    result = LookupBranch.new.execute(query: "Headquarters").find { |b| b[:name] == "Headquarters" }

    assert_equal [ "Engineering" ], result[:departments]
    device = result[:devices].find { |d| d[:name] == "Device One" }

    assert_equal [ "10.0.1.10" ], device[:ip_addresses].map { |ip| ip[:address] }
  end

  test "device ip history preloads without per-version queries" do
    device = devices(:one)
    ip = ip_addresses(:one)
    ip.update!(device: nil)
    ip.update!(device: device)

    result = GetDeviceIpHistory.new.execute(name: "Device One")
    actions = result[:history].map { |h| h[:action] }

    assert_includes actions, "assigned"
    assert_includes actions, "unassigned"
  end
end
