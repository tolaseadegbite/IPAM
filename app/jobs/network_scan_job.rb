class NetworkScanJob < ApplicationJob
  queue_as :monitoring

  def perform
    # Iterate through all subnets stored in DB
    Subnet.find_each do |subnet|
      # Convert Postgres CIDR object to string (e.g., "192.168.1.0/24")
      cidr_string = "#{subnet.network_address}/#{subnet.network_address.prefix}"

      NetworkReconService.scan_subnet(cidr_string)
    end
  end
end
