class UnassignIp < RubyLLM::Tool
  desc "Unassign an IP address from its device, making it available again."

  param :ip_address, desc: "The IP address to unassign (e.g. 192.168.1.100)"

  def execute(ip_address:)
    ip = IpAddress.find_by(address: ip_address)

    unless ip
      return "IP address #{ip_address} not found."
    end

    unless ip.device_id.present?
      return "IP #{ip_address} is not assigned to any device."
    end

    device_name = ip.device.name
    ip.update!(device: nil)

    "Unassigned IP #{ip_address} from #{device_name}. The IP is now available."
  end
end
