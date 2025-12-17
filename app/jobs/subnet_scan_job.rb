class SubnetScanJob < ApplicationJob
  queue_as :monitoring

  def perform(subnet_id, batch_id)
    subnet = Subnet.find(subnet_id)
    cidr = "#{subnet.network_address}/#{subnet.network_address.prefix}"

    # 1. Run the scan
    NetworkReconService.scan_subnet(cidr)

    # 2. Handle "Batch Completion"
    # We decrement the counter in the Cache. If 0, we are the last job.
    remaining = Rails.cache.decrement("scan_batch_#{batch_id}")
    
    if remaining == 0
      # We are the last one! Finish up.
      NetworkReconService.broadcast_global_stats
      Rails.logger.info "[SubnetScanJob] Batch #{batch_id} complete. Global stats broadcasted."
    end
  end
end