class FindIpByMac < RubyLLM::Tool
  desc "Find a device by its MAC address and show its assigned IPs."

  param :mac_address, desc: "MAC address to search for (formats: xx:xx:xx:xx:xx:xx, xx-xx-xx-xx-xx-xx, or xxxxxxxxxxxx)"

  def execute(mac_address:)
    normalized = mac_address.strip.downcase.gsub(/[^0-9a-f]/i, "")

    if normalized.length != 12
      return "Invalid MAC address format. Expected 12 hex characters (e.g. c0:18:03:b6:97:26)."
    end

    formatted = normalized.scan(/../).join(":")
    device = Device.find_by(mac_address: formatted)

    unless device
      similar = Device.where("mac_address ILIKE ?", "%#{normalized}%").limit(5).map do |d|
        { name: d.name, mac: d.mac_address }
      end
      if similar.any?
        list = similar.map { |s| "'#{s[:name]}' (#{s[:mac]})" }.to_sentence
        return "No device found with MAC #{mac_address}. Did you mean: #{list}?"
      end
      return "No device found with MAC #{mac_address}."
    end

    {
      id: device.id,
      name: device.name,
      type: device.device_type,
      status: device.status,
      mac_address: device.mac_address,
      location: device.location,
      department: device.department&.name,
      employee: device.employee&.full_name,
      ip_addresses: device.ip_addresses.map { |ip| ip.address.to_s }
    }
  end
end
