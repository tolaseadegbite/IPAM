class GetNetworkStats < RubyLLM::Tool
  desc "Get overall network statistics including IP usage, device counts, and subnet info"

  def execute
    {
      subnets: Subnet.count,
      total_ips: IpAddress.count,
      used_ips: IpAddress.where(status: :active).count,
      available_ips: IpAddress.where(status: :available).count,
      reserved_ips: IpAddress.where(status: :reserved).count,
      blacklisted_ips: IpAddress.where(status: :blacklisted).count,
      total_devices: Device.count,
      active_devices: Device.where(status: :active).count,
      reachable_ips: IpAddress.where(reachability_status: :up).count,
      unreachable_ips: IpAddress.where(reachability_status: :down).count,
      rogue_devices: IpAddress.rogue_only.count,
      total_employees: Employee.active.count
    }
  end
end
