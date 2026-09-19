class GetDeviceIpHistory < RubyLLM::Tool
  description "Show the IP assignment history for a device, including past and current IPs with timestamps."

  parameter :name, description: "The name of the device to look up"

  def execute(name:)
    device = Device.find_by(name: name)

    unless device
      return "Device '#{name}' not found. Use LookupDevice to search."
    end

    versions = PaperTrail::Version.where(item_type: "IpAddress")
                                  .where("object_changes LIKE ?", "%device_id%")
                                  .order(created_at: :desc)
                                  .limit(50)
                                  .to_a

    # One query for every referenced IP instead of one per version.
    ips_by_id = IpAddress.where(id: versions.map(&:item_id)).index_by(&:id)

    events = versions.filter_map do |version|
      changes = YAML.safe_load(version.object_changes || "{}")
      device_id_changes = changes["device_id"]
      next unless device_id_changes

      old_id, new_id = device_id_changes
      next unless [ old_id, new_id ].include?(device.id)

      ip_address = ips_by_id[version.item_id]&.address.to_s ||
        YAML.safe_load(version.object || "{}")["address"]

      action = if old_id == device.id && new_id.nil?
        "unassigned"
      elsif old_id.nil? && new_id == device.id
        "assigned"
      elsif old_id == device.id && new_id != device.id
        "reassigned to another device"
      elsif old_id != device.id && new_id == device.id
        "assigned (was on another device)"
      else
        "changed"
      end

      {
        ip: ip_address,
        action: action,
        at: version.created_at.strftime("%Y-%m-%d %H:%M UTC")
      }
    end

    current_ips = device.ip_addresses.map do |ip|
      { ip: ip.address.to_s, status: ip.status, reachability: ip.reachability_status }
    end

    {
      device: device.name,
      current_ips: current_ips,
      history: events
    }
  end
end
