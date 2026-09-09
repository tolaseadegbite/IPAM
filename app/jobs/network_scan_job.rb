class NetworkScanJob < ApplicationJob
  queue_as :monitoring

  def perform
    Rails.cache.write("scan_batch_start_time", Time.current)

    subnets = Subnet.all.to_a
    # Unique per run: second-resolution timestamps collide on rapid double-clicks.
    batch_id = "#{Time.current.to_i}-#{SecureRandom.hex(4)}"

    if subnets.empty?
      NetworkReconService.broadcast_global_stats
      Rails.logger.info "[NetworkScanJob] No subnets to scan. Broadcast idle stats."
      return
    end

    Rails.cache.write("scan_batch_#{batch_id}", subnets.count, expires_in: 1.hour)

    Rails.logger.info "[NetworkScanJob] Spawning #{subnets.count} parallel jobs (Batch #{batch_id})..."

    subnets.each do |subnet|
      SubnetScanJob.perform_later(subnet.id, batch_id)
    end
  end
end
