class NetworkReconService
  include BroadcastSafely
  # Entry point for scanning a specific subnet.
  def self.scan_subnet(subnet_cidr)
    new.scan_subnet(subnet_cidr)
  end

  # Entry point for the "Evening Summary".
  def self.broadcast_global_stats
    new.broadcast_dashboard_stats
  end

  def scan_subnet(subnet_cidr)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info "[NetworkRecon] Starting scan for #{subnet_cidr}..."

    # 1. Execute Nmap (System Call)
    windows_path_raw = "/mnt/c/Program Files (x86)/Nmap/nmap.exe"
    nmap_bin = File.exist?(windows_path_raw) ? "'#{windows_path_raw}'" : "sudo nmap"

    command = "#{nmap_bin} -sn -PR -n -T4 --min-parallelism 100 --max-rtt-timeout 250ms #{subnet_cidr}"
    output = `#{command}`

    # 2. Parse Results
    active_hosts = parse_nmap_output(output)

    # Pre-fetch existing records
    found_ips = active_hosts.map { |h| h[:ip] }
    ip_records_map = IpAddress.where(address: found_ips).index_by { |r| r.address.to_s }

    found_macs = active_hosts.map { |h| h[:mac] }.compact
    device_records_map = Device.where(mac_address: found_macs).index_by(&:mac_address)

    records_to_broadcast = []
    offline_records_to_broadcast =[]

    # 3. Process Updates (Transactional - FAST SQL ONLY)
    ActiveRecord::Base.transaction do
      # A. Update Online Hosts
      active_hosts.each do |host_data|
        ip_record = ip_records_map[host_data[:ip]]
        next unless ip_record

        updated_record = process_host_update(ip_record, host_data, device_records_map)
        records_to_broadcast << updated_record if updated_record
      end

      # B. Update Offline Hosts
      offline_ips = IpAddress.where("address <<= ?", subnet_cidr)
                             .where.not(address: found_ips)
                             .where(reachability_status: :up)

      offline_ids = offline_ips.pluck(:id)

      if offline_ids.any?
        IpAddress.where(id: offline_ids).update_all(reachability_status: :down)

        offline_records_to_broadcast = IpAddress.includes(:device, :subnet).where(id: offline_ids).to_a
        Rails.logger.info "[NetworkRecon] Marked #{offline_ids.count} hosts as OFFLINE in #{subnet_cidr}."
      end
    end
    # --- TRANSACTION CLOSES HERE. LOCK IS RELEASED. ---

    # 4. BULK HTML BROADCAST (One single SolidCable Database Write)
    # ----------------------------------------------------------------
    all_records = records_to_broadcast + offline_records_to_broadcast

    if all_records.any?
      # We use ApplicationController to render an inline template containing ALL turbo streams.
      streams_payload = ApplicationController.render(
        inline: "<% records.each do |ip| %><%= turbo_stream.replace ip, partial: 'ip_addresses/ip_address', locals: { ip_address: ip } %><% end %>",
        locals: { records: all_records }
      )

      # Send the massive combined payload as a single WebSocket message
      broadcast_safely do
        Turbo::StreamsChannel.broadcast_stream_to(
          "monitoring",
          content: streams_payload
        )
      end
    end

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = (end_time - start_time).round(2)
    Rails.logger.info "[NetworkRecon] Subnet scan completed in #{duration}s."
  end

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
    device_stats = Device.group(:device_type).count.transform_keys { |k| k.to_s.humanize }

    device_type_chart = {
      labels: device_stats.keys,
      datasets: [ {
        label: "Devices",
        data: device_stats.values,
        backgroundColor: [ "#6366f1", "#8b5cf6", "#ec4899", "#14b8a6", "#f59e0b", "#64748b" ],
        borderWidth: 0,
        borderRadius: 4,
        barThickness: 20
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
                              .includes(:ip_addresses)
                              .limit(10)

    recent_events = NetworkEvent.includes(:device)
                                .order(created_at: :desc)
                                .limit(10)

    # 4. Timestamp & Cache
    start_time = Rails.cache.read("scan_batch_start_time")
    duration = if start_time
                 (Time.current - start_time).round(2)
    else
                 0
    end

    Rails.cache.write("last_scan_duration", duration)

    last_scan = Time.current
    Rails.cache.write("last_network_scan_completed_at", last_scan)

    # --- Kanban Data ---
    high_priority_tasks = Card.where(priority: :high)
                              .includes(:list, :users, :referenceable)
                              .order(created_at: :desc)
                              .limit(5)

    # 5. Broadcast
    broadcast_safely do
      Turbo::StreamsChannel.broadcast_replace_to(
        "monitoring",
        target: "dashboard_metrics",
        partial: "dashboards/metrics",
        locals: {
          online_count: online_count,
          total_ips: total_ips,
          rogue_count: rogue_count,
          utilization_percent: utilization_percent,
          device_type_chart: device_type_chart,
          allocation_chart: allocation_chart,
          subnets: subnets,
          rogue_devices: rogue_devices,
          ghost_assets: ghost_assets,
          critical_devices: critical_devices,
          recent_events: recent_events,
          last_scan: last_scan,
          duration: duration,
          high_priority_tasks: high_priority_tasks,
          scanning: false
        }
      )
    end
  end

  private

  def process_host_update(ip_record, host_data, device_records_map)
    updates = {
      last_seen_at: Time.current,
      reachability_status: :up
    }

    if host_data[:mac].present?
      known_device = device_records_map[host_data[:mac]]

      if known_device
        # Scenario A: Drift Detected (Known device moved to this IP)
        if ip_record.device_id != known_device.id
          Rails.logger.info "[NetworkRecon] Drift detected: '#{known_device.name}' -> #{host_data[:ip]}"

          NetworkEvent.create!(
            kind: :drift,
            ip_address: host_data[:ip],
            device: known_device,
            message: "Device '#{known_device.name}' claimed #{host_data[:ip]}"
          )

          # --- SUBNET-AWARE DRIFT ---
          old_ips = IpAddress.where(device_id: known_device.id, subnet_id: ip_record.subnet_id)

          old_ips.where(status: :active).update_all(device_id: nil, status: :available)
          old_ips.update_all(device_id: nil)
          # -----------------------------------

          updates[:device_id] = known_device.id
        end

        # Scenario B: Status Consistency
        if ip_record.available? || updates[:device_id]
          updates[:status] = :active
        end

      else
        # --- SCENARIO C: Unknown MAC at an assigned IP ---

        if ip_record.device_id.present?
          current_device = ip_record.device

          if current_device
            if current_device.mac_address.nil?
              # Device was created without a MAC (e.g. from a photo import).
              # Adopt the discovered MAC instead of evicting.
              current_device.update!(mac_address: host_data[:mac])

              NetworkEvent.create!(
                kind: :info,
                ip_address: host_data[:ip],
                device: current_device,
                message: "MAC #{host_data[:mac]} adopted for '#{current_device.name}' (#{host_data[:ip]})."
              )

            elsif current_device.mac_address != host_data[:mac]
              Rails.logger.warn "[NetworkRecon] SECURITY ALERT: Unknown MAC #{host_data[:mac]} took over IP #{host_data[:ip]} from #{current_device.name}"

              NetworkEvent.create!(
                kind: :security,
                ip_address: host_data[:ip],
                device: current_device,
                message: "Unknown MAC (#{host_data[:mac]}) seized IP currently assigned to this device."
              )

              updates[:device_id] = nil
              updates[:status] = :available
            end
          end
        end
      end
    end

    # Apply updates and Trigger PaperTrail
    PaperTrail.request(whodunnit: "Network Scanner") do
      ip_record.assign_attributes(updates)

      if ip_record.changed?
        ip_record.save!
      end
    end

    # Return the record so it can be pushed into the broadcast array outside the lock
    ip_record
  end

  def parse_nmap_output(output)
    hosts =[]
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
