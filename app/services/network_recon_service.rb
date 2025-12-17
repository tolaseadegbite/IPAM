class NetworkReconService
  # Entry point for scanning a specific subnet.
  # This performs "Phase A" of the broadcast (individual IP updates).
  def self.scan_subnet(subnet_cidr)
    new.scan_subnet(subnet_cidr)
  end

  # Entry point for the "Evening Summary".
  # This performs "Phase B" (charts, totals, unlocking the UI).
  def self.broadcast_global_stats
    new.broadcast_dashboard_stats
  end

  def scan_subnet(subnet_cidr)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info "[NetworkRecon] Starting scan for #{subnet_cidr}..."

    # 1. Execute Nmap (System Call)
    # ----------------------------------------------------------------
    windows_path_raw = "/mnt/c/Program Files (x86)/Nmap/nmap.exe"
    nmap_bin = File.exist?(windows_path_raw) ? "'#{windows_path_raw}'" : "sudo nmap"

    # -sn: Ping Scan (disable port scan)
    # -PR: ARP Ping (fastest for local LAN)
    # -n:  No DNS resolution (speed optimization)

    # old command
    # command = "#{nmap_bin} -sn -PR -n #{subnet_cidr}"

    # new command (Fast & Aggressive):
    command = "#{nmap_bin} -sn -PR -n -T4 --min-parallelism 100 --max-rtt-timeout 100ms #{subnet_cidr}"

    output = `#{command}`

    # 2. Parse Results
    # ----------------------------------------------------------------
    active_hosts = parse_nmap_output(output)

    # Pre-fetch existing records to minimize N+1 queries during the loop
    found_ips = active_hosts.map { |h| h[:ip] }
    ip_records_map = IpAddress.where(address: found_ips).index_by { |r| r.address.to_s }

    found_macs = active_hosts.map { |h| h[:mac] }.compact
    device_records_map = Device.where(mac_address: found_macs).index_by(&:mac_address)

    # 3. Process Updates (Transactional)
    # ----------------------------------------------------------------
    ActiveRecord::Base.transaction do
      # A. Update Online Hosts
      active_hosts.each do |host_data|
        ip_record = ip_records_map[host_data[:ip]]
        next unless ip_record # Skip if IP isn't in our IPAM database

        # This triggers the "Phase A" broadcast (Green Dot pop-up)
        process_host_update(ip_record, host_data, device_records_map)
      end

      # B. Update Offline Hosts
      # Identify IPs in this subnet that were previously 'up' but were NOT found in this scan
      offline_ips = IpAddress.where("address <<= ?", subnet_cidr)
                             .where.not(address: found_ips)
                             .where(reachability_status: :up)

      offline_ids = offline_ips.pluck(:id)

      if offline_ids.any?
        IpAddress.where(id: offline_ids).update_all(reachability_status: :down)

        # Broadcast individual "Down" states immediately
        IpAddress.includes(:device, :subnet).where(id: offline_ids).each do |offline_ip|
          Turbo::StreamsChannel.broadcast_replace_to(
            "monitoring",
            target: offline_ip,
            partial: "ip_addresses/ip_address",
            locals: { ip_address: offline_ip }
          )
        end
        Rails.logger.info "[NetworkRecon] Marked #{offline_ids.count} hosts as OFFLINE in #{subnet_cidr}."
      end
    end

    # NOTE: We do NOT broadcast global stats here anymore.
    # We wait for the Job to finish all subnets.

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = (end_time - start_time).round(2)
    Rails.logger.info "[NetworkRecon] Subnet scan completed in #{duration}s."
  end

  # This method aggregates the final data and pushes the "Dashboard Refresh".
  # It is now public so the Job can call it at the very end.
  def broadcast_dashboard_stats
    Rails.logger.info "[NetworkRecon] Broadcasting Global Dashboard Stats..."

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

    # 3. Lists (Heavy queries, limited by scope)
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

    # 4. Timestamp & Cache
    last_scan = Time.current
    Rails.cache.write("last_network_scan_completed_at", last_scan)

    # 5. Broadcast (Phase B)
    # This replaces the `dashboard_metrics` container, updating charts, timestamps,
    # and crucially, setting `scanning: false` to unlock the UI button.
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
        subnets: subnets,
        rogue_devices: rogue_devices,
        ghost_assets: ghost_assets,
        critical_devices: critical_devices,
        recent_events: recent_events,
        last_scan: last_scan, # Explicit timestamp matching job finish
        scanning: false       # UNLOCK THE BUTTON
      }
    )
  end

  private

  def process_host_update(ip_record, host_data, device_records_map)
    updates = {
      last_seen_at: Time.current,
      reachability_status: :up
    }

    # Device association logic
    if host_data[:mac].present?
      known_device = device_records_map[host_data[:mac]]

      if known_device
        # Drift Detection: Did the device move IPs?
        if ip_record.device_id != known_device.id
          Rails.logger.info "[NetworkRecon] Drift detected: '#{known_device.name}' -> #{host_data[:ip]}"

          NetworkEvent.create!(
            kind: :drift,
            ip_address: host_data[:ip],
            device: known_device,
            message: "Device '#{known_device.name}' moved to #{host_data[:ip]}"
          )

          # Clear old associations for this device
          IpAddress.where(device_id: known_device.id).update_all(device_id: nil, status: :available)

          updates[:device_id] = known_device.id
        end

        # Auto-activate IP if it was available
        if ip_record.available?
          updates[:status] = :active
        end
      end
    end

    ip_record.update_columns(updates)
    ip_record.assign_attributes(updates) # Update in memory for the partial

    # Broadcast individual IP update (Phase A)
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
      mac_address = mac_match ? mac_match[1].downcase.gsub("-", ":") : nil

      hosts << { ip: ip_address, mac: mac_address }
    end
    hosts
  end
end
