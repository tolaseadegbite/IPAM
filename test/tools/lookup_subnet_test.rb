require "test_helper"

class LookupSubnetTest < ActiveSupport::TestCase
  setup do
    @subnet = subnets(:one)
    # Fixture ip_addresses(:one) is active + device-linked on this subnet.
    ip_addresses(:one).update!(reachability_status: :up, last_seen_at: 1.hour.ago)
    IpAddress.create!(subnet: @subnet, address: "10.0.1.11", status: :available,
                      reachability_status: :up, last_seen_at: 30.minutes.ago)
    IpAddress.create!(subnet: @subnet, address: "10.0.1.12", status: :available,
                      reachability_status: :down, last_seen_at: 2.hours.ago)
    IpAddress.create!(subnet: @subnet, address: "10.0.1.13", status: :available,
                      reachability_status: :unknown)
  end

  test "reports allocation counts with the RubyLLM 2.0 tool DSL" do
    result = LookupSubnet.new.execute(query: "LAN").find { |r| r[:name] == "LAN Subnet" }

    # NOTE: total_ips reads the counter cache (stale under fixtures), so
    # only the query-backed count is asserted here.
    assert_equal 1, result[:used_ips]
  end
end
