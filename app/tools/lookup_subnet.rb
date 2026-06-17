class LookupSubnet < RubyLLM::Tool
  desc "Search for subnets by name, network address, or VLAN ID"

  param :query, desc: "Subnet name, CIDR network address, or VLAN ID to search for"

  def execute(query:)
    Subnet.where("name ILIKE :q OR network_address::text ILIKE :q OR CAST(vlan_id AS text) ILIKE :q", q: "%#{query}%")
          .limit(20)
          .map do |s|
      total = s.ip_addresses.size
      used = s.ip_addresses.where(status: :active).size
      {
        id: s.id,
        name: s.name,
        network: s.network_address.to_s,
        gateway: s.gateway.to_s,
        vlan: s.vlan_id,
        total_ips: total,
        used_ips: used,
        available_ips: total - used,
        usage_percent: total > 0 ? (used.to_f / total * 100).round(1) : 0
      }
    end
  end
end
