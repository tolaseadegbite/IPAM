class LookupSubnet < RubyLLM::Tool
  description "Search for subnets by name, network address, or VLAN ID"

  parameter :query, description: "Subnet name, CIDR network address, or VLAN ID to search for"

  def execute(query:)
    Subnet.where("name ILIKE :q OR network_address::text ILIKE :q OR CAST(vlan_id AS text) ILIKE :q", q: "%#{query}%")
          .limit(20)
          .map do |s|
      total = s.ip_addresses.size
      used = s.ip_addresses.where(status: :active).size
      ips = s.ip_addresses
      {
        id: s.id,
        name: s.name,
        network: s.network_address.to_s,
        gateway: s.gateway.to_s,
        vlan: s.vlan_id,
        total_ips: total,
        used_ips: used,
        available_ips: total - used,
        usage_percent: total > 0 ? (used.to_f / total * 100).round(1) : 0,
        reachable_ips: ips.where(reachability_status: :up).size,
        unreachable_ips: ips.where(reachability_status: :down).size,
        unscanned_ips: ips.where(reachability_status: :unknown).size,
        last_seen_at: ips.maximum(:last_seen_at)&.iso8601
      }
    end
  end
end
