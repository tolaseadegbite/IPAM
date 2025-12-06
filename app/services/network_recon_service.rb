class NetworkReconService
  def self.scan_subnet(subnet_cidr)
    new.scan_subnet(subnet_cidr)
  end

  def scan_subnet(subnet_cidr)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Rails.logger.info "Starting Network Scan for #{subnet_cidr}..."

    windows_path_raw = "/mnt/c/Program Files (x86)/Nmap/nmap.exe"
    if File.exist?(windows_path_raw)
      nmap_bin = "'#{windows_path_raw}'"
    else
      nmap_bin = "sudo nmap"
    end

    command = "#{nmap_bin} -sn -PR -n #{subnet_cidr}"
    output = `#{command}`

    active_hosts = parse_nmap_output(output)

    # Batch Load Data
    found_ips = active_hosts.map { |h| h[:ip] }
    ip_records_map = IpAddress.where(address: found_ips).index_by { |r| r.address.to_s }

    found_macs = active_hosts.map { |h| h[:mac] }.compact
    device_records_map = Device.where(mac_address: found_macs).index_by(&:mac_address)

    ActiveRecord::Base.transaction do
      active_hosts.each do |host_data|
        ip_record = ip_records_map[host_data[:ip]]
        next unless ip_record

        updates = {
          last_seen_at: Time.current,
          reachability_status: :up
        }

        if host_data[:mac].present?
          known_device = device_records_map[host_data[:mac]]

          if known_device
            # Drift Logic
            if ip_record.device_id != known_device.id
              Rails.logger.info "DRIFT DETECTED: '#{known_device.name}' moved to #{host_data[:ip]}"

              # 1. Reset old 'Active' IPs to 'Available'
              IpAddress.where(device_id: known_device.id, status: :active)
                       .update_all(device_id: nil, status: :available)

              # 2. Reset old 'Reserved' IPs (Keep status, remove device)
              IpAddress.where(device_id: known_device.id)
                       .update_all(device_id: nil)

              updates[:device_id] = known_device.id
            end

            # Status Consistency Logic (New IP)
            if ip_record.available?
              updates[:status] = :active
            end
          end
        end

        ip_record.update_columns(updates)
      end
    end

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = (end_time - start_time).round(2)

    Rails.logger.info "Network Scan Completed: Found #{active_hosts.count} active hosts in #{duration} seconds."
  end

  private

  def parse_nmap_output(output)
    hosts = []
    reports = output.split("Nmap scan report for ")

    reports.each do |report|
      next if report.strip.empty?

      ip_match = report.match(/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/)
      next unless ip_match
      ip_address = ip_match[1]

      next unless report.include?("Host is up")

      mac_match = report.match(/MAC Address: ([0-9A-F:-]+)/i)

      if mac_match
        mac_address = mac_match[1].downcase.gsub("-", ":")
        hosts << { ip: ip_address, mac: mac_address }
      else
        hosts << { ip: ip_address, mac: nil }
      end
    end
    hosts
  end
end
