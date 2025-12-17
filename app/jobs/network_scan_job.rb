class NetworkScanJob < ApplicationJob
  queue_as :monitoring

  def perform
    subnets = Subnet.all.to_a
    batch_id = Time.current.to_i
    
    # Store the count of jobs we are about to launch
    Rails.cache.write("scan_batch_#{batch_id}", subnets.count)

    Rails.logger.info "[NetworkScanJob] Spawning #{subnets.count} parallel jobs (Batch #{batch_id})..."

    subnets.each do |subnet|
      # Fan out: Enqueue all jobs simultaneously
      SubnetScanJob.perform_later(subnet.id, batch_id)
    end
  end
end