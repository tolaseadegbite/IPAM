class LookupDevice < RubyLLM::Tool
  desc "Search for devices by name, MAC address, type, or location"

  param :query, desc: "Device name, MAC address, device type, or location to search for"

  def execute(query:)
    Device.left_joins(:department, :employee)
          .includes(:department, :employee)
          .where("devices.name ILIKE :q OR devices.mac_address ILIKE :q OR devices.location ILIKE :q OR departments.name ILIKE :q",
                 q: "%#{query}%")
          .limit(20)
          .map do |d|
      {
        id: d.id,
        name: d.name,
        type: d.device_type,
        status: d.status,
        mac_address: d.mac_address,
        location: d.location,
        critical: d.critical,
        department: d.department&.name,
        employee: d.employee&.full_name,
        ip_addresses: d.ip_addresses.map { |ip| ip.address.to_s },
        notes: d.notes
      }
    end
  end
end
