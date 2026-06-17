class SearchIps < RubyLLM::Tool
  desc "Search for IP addresses by address, device name, or subnet name"

  param :query, desc: "IP address, device name, or subnet name to search for"

  def execute(query:)
    IpAddress.left_joins(:device, :subnet)
             .includes(:device, :subnet)
             .where("host(ip_addresses.address) ILIKE :q OR devices.name ILIKE :q OR subnets.name ILIKE :q", q: "%#{query}%")
             .limit(20)
             .map do |ip|
      {
        address: ip.address.to_s,
        status: ip.status,
        reachability: ip.reachability_status,
        subnet: ip.subnet&.name,
        subnet_id: ip.subnet_id,
        device: ip.device&.name,
        device_id: ip.device_id,
        last_seen: ip.last_seen_at&.iso8601,
        notes: ip.notes
      }
    end
  end
end
