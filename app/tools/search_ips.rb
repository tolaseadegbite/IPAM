class SearchIps < RubyLLM::Tool
  description "Search for IP addresses by address, device name, or subnet name, optionally filtered by status, reachability, or subnet"

  parameter :query, description: "IP address, device name, or subnet name to search for", required: false
  parameter :status, description: "Filter by allocation status: available, active, reserved, or blacklisted (optional)", required: false
  parameter :reachability, description: "Filter by liveness: unknown, up, or down (optional)", required: false
  parameter :subnet_id, type: "integer", description: "Filter by subnet ID (optional)", required: false

  def execute(query: nil, status: nil, reachability: nil, subnet_id: nil)
    if status.present? && !IpAddress.statuses.key?(status)
      return "Invalid status '#{status}'. Valid values: #{IpAddress.statuses.keys.to_sentence}."
    end

    if reachability.present? && !IpAddress.reachability_statuses.key?(reachability)
      return "Invalid reachability '#{reachability}'. Valid values: #{IpAddress.reachability_statuses.keys.to_sentence}."
    end

    if subnet_id.present? && Subnet.find_by(id: subnet_id).nil?
      return "Subnet with ID #{subnet_id} not found. Use LookupSubnet to find the subnet ID."
    end

    scope = IpAddress.left_joins(:device, :subnet)
                     .includes(:device, :subnet)

    if query.present?
      scope = scope.where("host(ip_addresses.address) ILIKE :q OR devices.name ILIKE :q OR subnets.name ILIKE :q", q: "%#{query}%")
    end

    scope = scope.where(status: status) if status.present?
    scope = scope.where(reachability_status: reachability) if reachability.present?
    scope = scope.where(subnet_id: subnet_id) if subnet_id.present?

    rows = scope.limit(20).map do |ip|
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
