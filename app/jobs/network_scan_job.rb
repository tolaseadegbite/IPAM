class NetworkScanJob < ApplicationJob
  queue_as :monitoring

  def perform
    Rails.cache.write("scan_batch_start_time", Time.current)

    subnets = Subnet.all.to_a
    batch_id = Time.current.to_i
    
    Rails.cache.write("scan_batch_#{batch_id}", subnets.count)

    Rails.logger.info "[NetworkScanJob] Spawning #{subnets.count} parallel jobs (Batch #{batch_id})..."

    subnets.each do |subnet|
      SubnetScanJob.perform_later(subnet.id, batch_id)
    end
  end
end