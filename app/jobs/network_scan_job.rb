class NetworkScanJob < ApplicationJob
  queue_as :monitoring

  def perform
    Rails.logger.info "[NetworkScanJob] Starting scheduled network scan..."

    # 1. Iterate through all subnets (Phase A)
    # This process is blocking. The Dashboard button will remain "Scanning..." (pulsing)
    # while this loop runs, because we haven't sent the unlock signal yet.
    # Users will see individual IP cards updating in real-time.
    Subnet.find_each do |subnet|
      # Format the CIDR (e.g., "192.168.1.0/24")
      cidr_string = "#{subnet.network_address}/#{subnet.network_address.prefix}"

      NetworkReconService.scan_subnet(cidr_string)
    end

    # 2. Broadcast Global Summary (Phase B)
    # Now that ALL subnets are processed, we calculate the totals, generate the charts,
    # set the timestamp, and unlock the "Scan Now" button on the dashboard.
    NetworkReconService.broadcast_global_stats

    Rails.logger.info "[NetworkScanJob] Scan complete. Dashboard broadcast sent."
  end
end
