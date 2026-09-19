class CreateSubnet < RubyLLM::Tool
  description "Create a new subnet. Its IP rows are auto-populated and the gateway is reserved. CIDR, overlap, and gateway rules are validated."

  parameter :name, description: "Subnet name (must be unique, e.g. 'Office LAN (.20)')"
  parameter :network_address, description: "Network in CIDR notation (e.g. 192.168.20.0/24)"
  parameter :gateway, description: "Gateway address inside the subnet (e.g. 192.168.20.1)"
  parameter :vlan_id, type: "integer", description: "VLAN ID (optional)", required: false
  parameter :branch_name, description: "Branch to attach the subnet to (optional)", required: false

  def execute(name:, network_address:, gateway:, vlan_id: nil, branch_name: nil)
    branch = nil
    if branch_name.present?
      branch = Branch.find_by("name ILIKE ?", branch_name)
      unless branch
        similar = Branch.where("name ILIKE ?", "%#{branch_name}%").limit(5).pluck(:name)
        suggestions = similar.any? ? " Did you mean: #{similar.to_sentence}?" : ""
        return "Branch '#{branch_name}' not found.#{suggestions}"
      end
    end

    subnet = Subnet.new(
      name: name, network_address: network_address, gateway: gateway,
      vlan_id: vlan_id, branch: branch
    )

    if subnet.save
      "Created subnet '#{subnet.name}' (#{subnet.network_address}) with gateway #{subnet.gateway}#{subnet.vlan_id ? " on VLAN #{subnet.vlan_id}" : ""}#{branch ? " at #{branch.name}" : ""}. #{subnet.ip_addresses_count} IP rows ready."
    else
      "Failed to create subnet: #{subnet.errors.full_messages.to_sentence}."
    end
  end
end
