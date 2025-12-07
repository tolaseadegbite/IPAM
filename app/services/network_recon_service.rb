class NetworkReconService
  def self.scan_subnet(subnet_cidr)
    new.scan_subnet(subnet_cidr)
  end

  def scan_subnet(subnet_cidr)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Rails.logger.info "Starting Network Scan for #{subnet_cidr}..."

    windows_path_raw = "/mnt/c/Program Files (x86)/Nmap/nmap.exe"
    nmap_bin = File.exist?(windows_path_raw) ? "'#{windows_path_raw}'" : "sudo nmap"

    command = "#{nmap_bin} -sn -PR -n #{subnet_cidr}"
    output = `#{command}`

    active_hosts = parse_nmap_output(output)

    found_ips = active_hosts.map { |h| h[:ip] }
    ip_records_map = IpAddress.where(address: found_ips).index_by { |r| r.address.to_s }

    found_macs = active_hosts.map { |h| h[:mac] }.compact
    device_records_map = Device.where(mac_address: found_macs).index_by(&:mac_address)

    ActiveRecord::Base.transaction do
      # Part A: Online Hosts
      active_hosts.each do |host_data|
        ip_record = ip_records_map[host_data[:ip]]
        next unless ip_record
        process_host_update(ip_record, host_data, device_records_map)
      end

      # Part B: Offline Hosts
      offline_ips = IpAddress.where("address <<= ?", subnet_cidr)
                             .where.not(address: found_ips)
                             .where(reachability_status: :up)

      offline_ids = offline_ips.pluck(:id)

      if offline_ids.any?
        IpAddress.where(id: offline_ids).update_all(reachability_status: :down)

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

    # --- NEW: Broadcast Global Stats ---
    broadcast_dashboard_stats
    # -----------------------------------

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = (end_time - start_time).round(2)

    Rails.logger.info "Network Scan Completed: Found #{active_hosts.count} active hosts in #{duration} seconds."
  end

  private

  # NEW METHOD: Calculates totals and updates the Charts/Big Numbers
  def broadcast_dashboard_stats
    # 1. Aggregates
    stats = IpAddress.group(:reachability_status, :device_id).count
    total_ips = IpAddress.count
    online_count = stats.select { |(reach, _), _| reach == "up" }.values.sum
    rogue_count = stats.select { |(reach, dev_id), _| reach == "up" && dev_id.nil? }.values.sum
    used_count = IpAddress.where(status: [ :active, :reserved ]).count
    utilization_percent = total_ips > 0 ? (used_count.to_f / total_ips * 100).to_i : 0

    # 2. Charts
    reachability_chart = {
      labels: [ "Online", "Offline" ],
      datasets: [ {
        data: [ online_count, total_ips - online_count ],
        backgroundColor: [ "#22c55e", "#f3f4f6" ],
        borderWidth: 0
      } ]
    }

    allocation_stats = IpAddress.group(:status).count
    allocation_chart = {
      labels: [ "Active", "Reserved", "Available", "Blacklisted" ],
      datasets: [ {
        data: [
          allocation_stats["active"] || 0,
          allocation_stats["reserved"] || 0,
          allocation_stats["available"] || 0,
          allocation_stats["blacklisted"] || 0
        ],
        backgroundColor: [ "#0ea5e9", "#eab308", "#22c55e", "#ef4444" ],
        borderWidth: 0
      } ]
    }

    # 3. Lists (Re-fetching fresh data for the dashboard)
    subnets = Subnet.joins("LEFT JOIN ip_addresses ON ip_addresses.subnet_id = subnets.id")
                     .select("subnets.id, subnets.name, subnets.network_address,
                              COUNT(ip_addresses.id) as total_ips,
                              COUNT(CASE WHEN ip_addresses.status IN (1, 2) THEN 1 END) as used_ips")
                     .group("subnets.id")
                     .order("used_ips DESC")

    rogue_devices = IpAddress.reachability_status_up
                              .where(device_id: nil)
                              .includes(:subnet)
                              .order(last_seen_at: :desc)
                              .limit(5)

    ghost_assets = IpAddress.active
                             .where(reachability_status: :down)
                             .where("last_seen_at < ?", 30.days.ago)
                             .includes(:device, :subnet)
                             .limit(5)

    critical_devices = Device.where(critical: true)
                              .includes(:ip_address)
                              .limit(10)

    recent_events = NetworkEvent.includes(:device)
                                .order(created_at: :desc)
                                .limit(10)

    # 4. Broadcast the WHOLE Partial
    # Broadcast the partial with scanning: false
    Turbo::StreamsChannel.broadcast_replace_to(
      "monitoring",
      target: "dashboard_metrics",
      partial: "dashboards/metrics",
      locals: {
        online_count: online_count,
        total_ips: total_ips,
        rogue_count: rogue_count,
        utilization_percent: utilization_percent,
        reachability_chart: reachability_chart,
        allocation_chart: allocation_chart,
        # ... pass subnets, rogues, etc ...
        subnets: subnets,
        rogue_devices: rogue_devices,
        ghost_assets: ghost_assets,
        critical_devices: critical_devices,
        recent_events: recent_events,

        scanning: false # <--- RESTORES THE BUTTON
      }
    )
  end

  def process_host_update(ip_record, host_data, device_records_map)
    updates = {
      last_seen_at: Time.current,
      reachability_status: :up
    }

    if host_data[:mac].present?
      known_device = device_records_map[host_data[:mac]]

      if known_device
        if ip_record.device_id != known_device.id
          Rails.logger.info "DRIFT DETECTED: '#{known_device.name}' moved to #{host_data[:ip]}"

          NetworkEvent.create!(
            kind: :drift,
            ip_address: host_data[:ip],
            device: known_device,
            message: "Device '#{known_device.name}' moved from previous location to #{host_data[:ip]}"
          )

          IpAddress.where(device_id: known_device.id, status: :active)
                   .update_all(device_id: nil, status: :available)

          IpAddress.where(device_id: known_device.id)
                   .update_all(device_id: nil)

          updates[:device_id] = known_device.id
        end

        if ip_record.available?
          updates[:status] = :active
        end
      end
    end

    ip_record.update_columns(updates)
    ip_record.assign_attributes(updates)

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
        mac_address = mac_match[1].downcase.gsub("-", ":")
        hosts << { ip: ip_address, mac: mac_address }
      else
        hosts << { ip: ip_address, mac: nil }
      end
    end
    hosts
  end
end
