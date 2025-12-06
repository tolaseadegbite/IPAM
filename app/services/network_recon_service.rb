class NetworkReconService
  def self.scan_subnet(subnet_cidr)
    new.scan_subnet(subnet_cidr)
  end

  def scan_subnet(subnet_cidr)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Rails.logger.info "Starting Network Scan for #{subnet_cidr}..."

    # 1. Prepare Command
    windows_path_raw = "/mnt/c/Program Files (x86)/Nmap/nmap.exe"
    nmap_bin = File.exist?(windows_path_raw) ? "'#{windows_path_raw}'" : "sudo nmap"
    
    # -n is crucial for speed (No DNS)
    command = "#{nmap_bin} -sn -PR -n #{subnet_cidr}"
    output = `#{command}`

    # 2. Parse Output
    active_hosts = parse_nmap_output(output)

    # 3. Batch Load Data (Performance)
    found_ips = active_hosts.map { |h| h[:ip] }
    ip_records_map = IpAddress.where(address: found_ips).index_by { |r| r.address.to_s }

    found_macs = active_hosts.map { |h| h[:mac] }.compact
    device_records_map = Device.where(mac_address: found_macs).index_by(&:mac_address)

    # 4. Process Updates
    ActiveRecord::Base.transaction do
      # --- Part A: Handle ONLINE Hosts (Green) ---
      active_hosts.each do |host_data|
        # In-Memory Lookup
        ip_record = ip_records_map[host_data[:ip]]
        next unless ip_record

        # Delegate logic to private method
        process_host_update(ip_record, host_data, device_records_map)
      end

      # --- Part B: Handle OFFLINE Hosts (Red/Gray) ---
      # This logic ensures devices that disappear update in Real-Time.
      
      # 1. Find IPs in this subnet that were previously 'UP' but were NOT found in this scan
      offline_ips = IpAddress.where("address <<= ?", subnet_cidr) # Belong to subnet
                             .where.not(address: found_ips)       # Not in current scan
                             .where(reachability_status: :up)     # Currently marked Up

      # 2. Capture IDs before updating (so we know who to broadcast)
      offline_ids = offline_ips.pluck(:id)

      if offline_ids.any?
        # 3. Bulk Update DB (Fastest way to mark them down)
        IpAddress.where(id: offline_ids).update_all(reachability_status: :down)

        # 4. Real-Time Broadcast for Offline Hosts
        # We must re-fetch them to get the correct state for the View
        IpAddress.includes(:device, :subnet).where(id: offline_ids).each do |offline_ip|
          Turbo::StreamsChannel.broadcast_replace_to(
            "monitoring",
            target: offline_ip,
            partial: "ip_addresses/ip_address",
            locals: { ip_address: offline_ip }
          )
        end
        Rails.logger.info "Marked #{offline_ids.count} hosts as OFFLINE."
      end
    end

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = (end_time - start_time).round(2)

    Rails.logger.info "Network Scan Completed: Found #{active_hosts.count} active hosts in #{duration} seconds."
  end

  private

  # This contains the Drift Logic + DB Update + Turbo Broadcast for ONLINE hosts
  def process_host_update(ip_record, host_data, device_records_map)
    updates = {
      last_seen_at: Time.current,
      reachability_status: :up
    }

    if host_data[:mac].present?
      known_device = device_records_map[host_data[:mac]]

      if known_device
        # Scenario A: Drift Detected
        if ip_record.device_id != known_device.id
          Rails.logger.info "DRIFT DETECTED: '#{known_device.name}' moved to #{host_data[:ip]}"

          # Reset old records
          IpAddress.where(device_id: known_device.id, status: :active)
                   .update_all(device_id: nil, status: :available)
          
          IpAddress.where(device_id: known_device.id)
                   .update_all(device_id: nil)

          updates[:device_id] = known_device.id
        end

        # Scenario B: Status Consistency
        if ip_record.available?
          updates[:status] = :active
        end
      end
    end

    # 1. Update Database (Fast, no callbacks)
    ip_record.update_columns(updates)

    # 2. Update Memory (Required for Turbo to see the changes)
    ip_record.assign_attributes(updates)

    # 3. Broadcast to UI (Real-Time Update)
    Turbo::StreamsChannel.broadcast_replace_to(
      "monitoring",
      target: ip_record,
      partial: "ip_addresses/ip_address",
      locals: { ip_address: ip_record }
    )
  end

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
        mac_address = mac_match[1].downcase.gsub('-', ':')
        hosts << { ip: ip_address, mac: mac_address }
      else
        hosts << { ip: ip_address, mac: nil }
      end
    end
    hosts
  end
end