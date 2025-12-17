class DashboardsController < ApplicationController
  def show
    load_dashboard_data
    render :show, locals: dashboard_locals(scanning: false)
  end

  def scan
    NetworkScanJob.perform_later
    load_dashboard_data # Reload data to get current state for the immediate response

    # Broadcast "Scanning..." state immediately to lock the button
    Turbo::StreamsChannel.broadcast_replace_to(
      "monitoring",
      target: "dashboard_metrics",
      partial: "dashboards/metrics",
      locals: dashboard_locals(scanning: true)
    )

    head :ok
  end

  private

  def load_dashboard_data
    # 1. Aggregates
    stats = IpAddress.group(:reachability_status, :device_id).count
    @total_ips = IpAddress.count
    @online_count = stats.select { |(reach, _), _| reach == "up" }.values.sum
    @rogue_count = stats.select { |(reach, dev_id), _| reach == "up" && dev_id.nil? }.values.sum
    used_count = IpAddress.where(status: [ :active, :reserved ]).count
    @utilization_percent = @total_ips > 0 ? (used_count.to_f / @total_ips * 100).to_i : 0

    # 2. Charts
    @reachability_chart = {
      labels: [ "Online", "Offline" ],
      datasets: [ {
        data: [ @online_count, @total_ips - @online_count ],
        backgroundColor: [ "#22c55e", "#f3f4f6" ],
        borderWidth: 0
      } ]
    }

    allocation_stats = IpAddress.group(:status).count
    @allocation_chart = {
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

    # 3. Lists
    @subnets = Subnet.joins("LEFT JOIN ip_addresses ON ip_addresses.subnet_id = subnets.id")
                     .select("subnets.id, subnets.name, subnets.network_address,
                              COUNT(ip_addresses.id) as total_ips,
                              COUNT(CASE WHEN ip_addresses.status IN (1, 2) THEN 1 END) as used_ips")
                     .group("subnets.id")
                     .order("used_ips DESC")

    @rogue_devices = IpAddress.reachability_status_up.where(device_id: nil).includes(:subnet).order(last_seen_at: :desc).limit(5)
    @ghost_assets = IpAddress.active.where(reachability_status: :down).where("last_seen_at < ?", 30.days.ago).includes(:device, :subnet).limit(5)
    @critical_devices = Device.where(critical: true).includes(:ip_address).limit(10)
    @recent_events = NetworkEvent.includes(:device).order(created_at: :desc).limit(10)

    # 4. Timestamp (NEW)
    # Read from cache to match the Service, fallback to DB, fallback to Now
    @last_scan = Rails.cache.read("last_network_scan_completed_at") || IpAddress.maximum(:last_seen_at) || Time.current

    # 5. Duration (NEW)
    @last_duration = Rails.cache.read("last_scan_duration") || 0
  end
  
  def dashboard_locals(scanning: false)
    {
      online_count: @online_count,
      total_ips: @total_ips,
      rogue_count: @rogue_count,
      utilization_percent: @utilization_percent,
      reachability_chart: @reachability_chart,
      allocation_chart: @allocation_chart,
      subnets: @subnets,
      rogue_devices: @rogue_devices,
      ghost_assets: @ghost_assets,
      critical_devices: @critical_devices,
      recent_events: @recent_events,
      last_scan: @last_scan,
      duration: @last_duration,
      scanning: scanning
    }
  end
end
