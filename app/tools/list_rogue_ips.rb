class ListRogueIps < RubyLLM::Tool
  description "List live hosts with no registered device (reachable but unassigned), optionally scoped to one subnet. Use this for 'unknown devices on the network' questions."

  parameter :subnet_id, type: "integer", description: "Subnet ID to scope to (optional)", required: false
  parameter :query, description: "Subnet name or CIDR fragment to scope to (optional, ignored when subnet_id is given)", required: false
  parameter :limit, type: "integer", description: "Max rows to return, capped at 50 (default: 20)", required: false

  def execute(subnet_id: nil, query: nil, limit: 20)
    scope = IpAddress.rogue_only.includes(:subnet)

    if subnet_id.present?
      subnet = Subnet.find_by(id: subnet_id)
      return "Subnet with ID #{subnet_id} not found. Use LookupSubnet to find the subnet ID." unless subnet

      scope = scope.where(subnet_id: subnet.id)
    elsif query.present?
      scope = scope.joins(:subnet).where(
        "subnets.name ILIKE :q OR subnets.network_address::text ILIKE :q", q: "%#{query}%"
      )
    end

    rows = scope.order(last_seen_at: :desc).limit([ limit.to_i, 50 ].min).map do |ip|
      {
        address: ip.address.to_s,
        subnet: ip.subnet&.name,
        subnet_id: ip.subnet_id,
        status: ip.status,
        last_seen: ip.last_seen_at&.iso8601
      }
    end

    return "No live unregistered hosts found." if rows.empty?

    rows
  end
end
