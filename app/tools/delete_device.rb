class DeleteDevice < RubyLLM::Tool
  desc "Delete a device by name. IPs assigned to it will be freed (set to unassigned)."

  param :name, desc: "The name of the device to delete"

  def execute(name:)
    device = Device.includes(:ip_addresses).find_by(name: name)

    unless device
      return "Device named '#{name}' not found. Use LookupDevice to search for devices."
    end

    if device.cards.any?
      return "Device '#{name}' has #{device.cards.count} card(s) linked to it. Remove or reassign them before deleting."
    end

    NetworkEvent.where(device_id: device.id).update_all(device_id: nil)
    device.destroy!

    "Deleted device '#{name}' (#{device.device_type}). Its IPs have been freed."
  end
end
