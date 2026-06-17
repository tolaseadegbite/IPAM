class FindFreeIps < RubyLLM::Tool
  desc "Find truly free (unused) IP addresses in a subnet. Free IPs have no device assigned and no reachability activity."

  param :subnet_id, type: "integer", desc: "The subnet ID to search for free IPs in"
  param :count, type: "integer", desc: "Number of free IPs to return (default: 5)", required: false

  def execute(subnet_id:, count: 5)
    subnet = Subnet.find(subnet_id)

    subnet.ip_addresses
          .where(device_id: nil, reachability_status: :unknown)
          .where.not(status: :reserved)
          .limit(count)
          .map do |ip|
      {
        address: ip.address.to_s,
        subnet: subnet.name,
        subnet_id: subnet.id,
        status: ip.status,
        reachability: ip.reachability_status
      }
    end
  end
end
