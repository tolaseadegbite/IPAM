class LookupDevice < RubyLLM::Tool
  desc "Search for devices by name, MAC address, type, location, or filter by MAC/IP presence"

  param :query, desc: "Device name, MAC address, device type, or location to search for (ignored when has_mac or has_ip filters are used)"
  param :has_mac, desc: "Filter by MAC address presence: true = has MAC, false = no MAC", required: false
  param :has_ip, desc: "Filter by IP assignment: true = has IP(s), false = no IPs", required: false

  def execute(query: nil, has_mac: nil, has_ip: nil)
    has_mac = ActiveRecord::Type::Boolean.new.cast(has_mac) unless has_mac.nil?
    has_ip = ActiveRecord::Type::Boolean.new.cast(has_ip) unless has_ip.nil?

    scope = Device.left_joins(:department, :employee)
                  .includes(:department, :employee)
                  .limit(20)

    if query.present?
      scope = scope.where(
        "devices.name ILIKE :q OR devices.mac_address ILIKE :q OR devices.location ILIKE :q OR departments.name ILIKE :q",
        q: "%#{query}%"
      )
    end

    unless has_mac.nil?
      scope = has_mac ? scope.where.not(mac_address: nil) : scope.where(mac_address: nil)
    end

    unless has_ip.nil?
      ip_subquery = IpAddress.select(:device_id).where("ip_addresses.device_id = devices.id")
      scope = has_ip ? scope.where(ip_subquery.arel.exists) : scope.where(ip_subquery.arel.exists.not)
    end

    scope.map do |d|
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
