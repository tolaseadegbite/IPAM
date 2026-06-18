class AssignIpToDevice < RubyLLM::Tool
  desc "Assign an IP address to a device. Requires the IP address string and device name."

  param :ip_address, desc: "The IP address to assign (e.g. 192.168.1.100)"
  param :device_name, desc: "The name of the device to assign the IP to"

  def execute(ip_address:, device_name:)
    ip = IpAddress.find_by(address: ip_address)
    device = Device.find_by(name: device_name)

    unless ip
      return "IP address #{ip_address} not found. Use SearchIps or FindFreeIps to locate available IPs."
    end

    unless device
      return "Device named '#{device_name}' not found. Use LookupDevice to search for devices."
    end

    if ip.device_id.present?
      current_device = ip.device
      return "IP #{ip_address} is already assigned to #{current_device.name} (#{current_device.device_type}). Please unassign it first."
    end

    if ip.blacklisted?
      return "IP #{ip_address} is blacklisted and cannot be assigned to a device. Choose a different IP."
    end

    ip.update!(device: device)

    "Assigned IP #{ip_address} to device #{device.name} (#{device.device_type}) in #{device.department_name}."
  end
end
