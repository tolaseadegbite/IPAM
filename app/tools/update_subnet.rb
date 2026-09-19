class UpdateSubnet < RubyLLM::Tool
  description "Update an existing subnet's fields. Only provided fields will be changed."

  parameter :query, description: "Subnet name or CIDR fragment identifying the subnet"
  parameter :name, description: "New subnet name", required: false
  parameter :gateway, description: "New gateway address (must stay inside the subnet)", required: false
  parameter :vlan_id, type: "integer", description: "New VLAN ID", required: false
  parameter :branch_name, description: "Branch to attach the subnet to", required: false

  def execute(query:, name: nil, gateway: nil, vlan_id: nil, branch_name: nil)
    matches = Subnet.where(
      "name ILIKE :q OR network_address::text ILIKE :q", q: "%#{query}%"
    ).limit(2).to_a

    if matches.empty?
      return "Subnet '#{query}' not found. Use LookupSubnet to search."
    end

    if matches.size > 1
      names = matches.map { |s| "'#{s.name}' (#{s.network_address})" }.to_sentence
      return "Multiple subnets match '#{query}': #{names}. Ask the user which one."
    end

    subnet = matches.first
    changes = []
    changes << "name to '#{name}'" if name.present?
    changes << "gateway to #{gateway}" if gateway.present?
    changes << "VLAN to #{vlan_id}" unless vlan_id.nil?
    changes << "branch to #{branch_name}" if branch_name.present?

    if changes.empty?
      return "No changes provided. Specify at least one field to update."
    end

    if branch_name.present?
      branch = Branch.find_by("name ILIKE ?", branch_name)
      unless branch
        similar = Branch.where("name ILIKE ?", "%#{branch_name}%").limit(5).pluck(:name)
        suggestions = similar.any? ? " Did you mean: #{similar.to_sentence}?" : ""
        return "Branch '#{branch_name}' not found.#{suggestions}"
      end
      subnet.branch = branch
    end

    subnet.name = name if name.present?
    subnet.gateway = gateway if gateway.present?
    subnet.vlan_id = vlan_id unless vlan_id.nil?

    if subnet.save
      "Updated subnet '#{subnet.name}': #{changes.to_sentence}."
    else
      "Failed to update subnet: #{subnet.errors.full_messages.to_sentence}."
    end
  end
end
