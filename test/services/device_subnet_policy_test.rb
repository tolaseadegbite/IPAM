require "test_helper"

class DeviceSubnetPolicyTest < ActiveSupport::TestCase
  setup do
    @subnets = {}
    {
      "Yale 12" => "172.12.242.0/24",
      "Yale 15" => "172.15.242.0/24",
      "Yale 16" => "172.16.242.0/24",
      "Radio" => "192.168.1.0/24",
      "Corporate" => "192.168.13.0/24",
      "Contract" => "192.168.14.0/24",
      "Alt Corp" => "192.168.30.0/24"
    }.each do |name, cidr|
      base = cidr.split("/").first.split(".")[0..2].join(".")
      @subnets[name] = Subnet.create!(
        name: name, network_address: cidr, gateway: "#{base}.1"
      )
    end
  end

  def ip_in(name, host)
    base = @subnets[name].network_address.to_s.split("/").first.split(".")[0..2].join(".")
    IpAddress.find_by!(address: "#{base}.#{host}")
  end

  test "duplicate series is a violation" do
    messages = DeviceSubnetPolicy.violations([ ip_in("Corporate", 10).id, ip_in("Corporate", 11).id ])

    assert_equal 1, messages.size
    assert_match(/one series per device/i, messages.first)
  end

  test "corporate and alt-corp together is a violation" do
    messages = DeviceSubnetPolicy.violations([ ip_in("Corporate", 10).id, ip_in("Alt Corp", 10).id ])

    assert_equal 1, messages.size
    assert_match(/either side, not both/i, messages.first)
  end

  test "the two internet legs together is a violation" do
    messages = DeviceSubnetPolicy.violations([ ip_in("Yale 15", 10).id, ip_in("Yale 16", 10).id ])

    assert_equal 1, messages.size
  end

  test "legitimate multi-homed sets are clean" do
    assert_empty DeviceSubnetPolicy.violations([ ip_in("Yale 16", 10).id, ip_in("Corporate", 10).id ])
    assert_empty DeviceSubnetPolicy.violations([ ip_in("Corporate", 10).id, ip_in("Yale 15", 10).id ])
  end

  test "single ips and empty sets are clean" do
    assert_empty DeviceSubnetPolicy.violations([ ip_in("Corporate", 10).id ])
    assert_empty DeviceSubnetPolicy.violations([])
  end

  test "unknown ids are ignored" do
    assert_empty DeviceSubnetPolicy.violations([ -1 ])
  end

  test "max rows deducts only pairs present in inventory" do
    assert_equal Subnet.count - 2, DeviceSubnetPolicy.max_rows

    Subnet.where(name: [ "Corporate", "Alt Corp", "Yale 15", "Yale 16" ]).destroy_all

    assert_equal Subnet.count, DeviceSubnetPolicy.max_rows
  end
end
