require "test_helper"

class NatNewToolsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @subnet = subnets(:one)
    # Rogue: live but unregistered.
    IpAddress.create!(subnet: @subnet, address: "10.0.1.60", status: :available,
                      reachability_status: :up, last_seen_at: 1.hour.ago)
    # Live but registered: not rogue.
    IpAddress.create!(subnet: @subnet, address: "10.0.1.61", status: :active,
                      reachability_status: :up, device: devices(:one), last_seen_at: 1.hour.ago)
    # Unregistered but dark: not rogue.
    IpAddress.create!(subnet: @subnet, address: "10.0.1.62", status: :available,
                      reachability_status: :down, last_seen_at: 1.hour.ago)
  end

  test "list_rogue_ips returns only live unregistered hosts" do
    result = ListRogueIps.new.execute(subnet_id: @subnet.id)

    assert_equal [ "10.0.1.60" ], result.map { |r| r[:address] }
  end

  test "list_rogue_ips reports empty subnets" do
    result = ListRogueIps.new.execute(subnet_id: subnets(:two).id)

    assert_match(/no live unregistered hosts/i, result)
  end

  test "list_rogue_ips rejects unknown subnets" do
    result = ListRogueIps.new.execute(subnet_id: -1)

    assert_match(/not found/i, result)
  end

  test "scan_subnet enqueues a rescan with a tracked batch" do
    assert_enqueued_with(job: SubnetScanJob) do
      result = ScanSubnet.new.execute(subnet_id: @subnet.id)

      assert_match(/rescan of 'LAN Subnet'/i, result)
    end
  end

  test "scan_subnet asks on ambiguous queries" do
    result = ScanSubnet.new.execute(query: "Subnet")

    assert_match(/multiple subnets/i, result)
  end

  test "scan_subnet reports unknown subnets" do
    result = ScanSubnet.new.execute(query: "No Such Net")

    assert_match(/not found/i, result)
  end

  test "search_ips filters by reachability and subnet" do
    result = SearchIps.new.execute(reachability: "up", subnet_id: @subnet.id)

    assert_includes result.map { |r| r[:address] }, "10.0.1.60"
    assert result.all? { |r| r[:reachability] == "up" }
  end

  test "search_ips rejects invalid filters with the valid list" do
    assert_match(/available, active, reserved/i, SearchIps.new.execute(status: "bogus"))
    assert_match(/unknown, up/i, SearchIps.new.execute(reachability: "bogus"))
    assert_match(/not found/i, SearchIps.new.execute(subnet_id: -1))
  end

  test "create_subnet builds rows and reserves the gateway" do
    result = CreateSubnet.new.execute(
      name: "Lab (.99)", network_address: "192.168.99.0/30", gateway: "192.168.99.1"
    )

    assert_match(/created subnet/i, result)
    subnet = Subnet.find_by(name: "Lab (.99)")
    gw = subnet.ip_addresses.find_by(address: "192.168.99.1")

    assert_equal "reserved", gw.status
  end

  test "create_subnet surfaces overlap errors" do
    result = CreateSubnet.new.execute(
      name: "Clash", network_address: "10.0.1.0/24", gateway: "10.0.1.1"
    )

    assert_match(/failed to create subnet/i, result)
  end

  test "create_subnet suggests similar branches" do
    result = CreateSubnet.new.execute(
      name: "Branchy", network_address: "192.168.98.0/30", gateway: "192.168.98.1",
      branch_name: "Headquarter"
    )

    assert_match(/did you mean/i, result)
    assert_match(/headquarters/i, result)
  end

  test "create_subnet reports unknown branches plainly" do
    result = CreateSubnet.new.execute(
      name: "Branchy", network_address: "192.168.98.0/30", gateway: "192.168.98.1",
      branch_name: "No Such Branch"
    )

    assert_match(/not found/i, result)
  end

  test "update_subnet asks on ambiguity before renaming" do
    ambiguous = UpdateSubnet.new.execute(query: "Subnet", name: "X")

    assert_match(/multiple subnets/i, ambiguous)

    result = UpdateSubnet.new.execute(query: "LAN Subnet", name: "LAN Renamed")

    assert_match(/renamed/i, result)
    assert_equal "LAN Renamed", @subnet.reload.name
  end

  test "update_subnet validates gateway and requires changes" do
    assert_match(/no changes/i, UpdateSubnet.new.execute(query: "LAN Subnet"))
    assert_match(
      /failed to update/i, UpdateSubnet.new.execute(query: "LAN Subnet", gateway: "10.9.9.9")
    )
  end
end
