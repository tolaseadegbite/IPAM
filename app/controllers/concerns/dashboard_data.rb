module DashboardData
  extend ActiveSupport::Concern

  TREND_DAYS = 14
  TREND_COLORS = {
    "info" => "#0ea5e9",
    "drift" => "#f59e0b",
    "outage" => "#ef4444",
    "security" => "#f97316"
  }.freeze

  # Shared by DashboardsController and NetworkReconService so the live
  # dashboard and scan broadcasts always render the same partial shape.
  # URL + date helpers go through global proxies so this works outside
  # of a request (jobs/services) as well as inside controllers.
  def build_events_trend
    days = (TREND_DAYS - 1).downto(0).map { |n| n.days.ago.to_date }
    counts = Hash.new { |h, k| h[k] = Hash.new(0) }
    NetworkEvent.where("created_at >= ?", days.first.beginning_of_day)
                .pluck(:created_at, :kind)
                .each { |at, kind| counts[at.to_date][kind] += 1 }

    {
      labels: days.map { |d| d.strftime("%b %-d") },
      datasets: NetworkEvent.kinds.keys.map do |kind|
        {
          label: kind.humanize,
          data: days.map { |d| counts[d][kind] },
          backgroundColor: TREND_COLORS.fetch(kind, "#64748b"),
          borderWidth: 0,
          borderRadius: 2,
          barPercentage: 0.7,
          categoryPercentage: 0.8
        }
      end
    }
  end

  def build_attention_queue(rogue_devices:, ghost_assets:, critical_devices:, high_priority_tasks:)
    routes = Rails.application.routes.url_helpers
    time_ago = ActionController::Base.helpers
    items = []

    NetworkEvent.where(kind: [ :outage, :security ]).includes(:device).order(created_at: :desc).limit(3).each do |event|
      items << {
        severity: :critical,
        icon: event.kind_security? ? "triangle-alert" : "monitor-x",
        title: event.message.to_s.truncate(70),
        subtitle: [ event.ip_address, event.device&.name ].compact.join(" · "),
        path: event.device ? routes.device_path(event.device) : nil,
        age: event.created_at
      }
    end

    critical_devices.each do |device|
      ips = device.ip_addresses.to_a
      next if ips.empty? || ips.any?(&:reachability_status_up?)

      items << {
        severity: :critical,
        icon: "monitor-x",
        title: "#{device.name} is offline",
        subtitle: ips.first ? "Critical · #{ips.first.address}" : "Critical · no IP assigned",
        path: routes.device_path(device),
        age: ips.filter_map(&:last_seen_at).max
      }
    end

    rogue_devices.each do |ip|
      items << {
        severity: :high,
        icon: "triangle-alert",
        title: "Rogue device at #{ip.address}",
        subtitle: ip.subnet&.name,
        path: routes.ip_address_path(ip),
        age: ip.last_seen_at
      }
    end

    ghost_assets.each do |ip|
      items << {
        severity: :medium,
        icon: "history",
        title: "Reclaim #{ip.device&.name || ip.address}",
        subtitle: ip.last_seen_at ? "Unseen #{time_ago.time_ago_in_words(ip.last_seen_at)}" : "Ghost asset",
        path: routes.ip_address_path(ip),
        age: ip.last_seen_at
      }
    end

    high_priority_tasks.each do |card|
      items << {
        severity: :medium,
        icon: "kanban",
        title: card.title,
        subtitle: card.list&.name,
        path: routes.edit_card_path(card),
        modal: true,
        age: card.created_at
      }
    end

    rank = { critical: 0, high: 1, medium: 2 }
    items.sort_by { |i| [ rank.fetch(i[:severity], 3), -(i[:age]&.to_i || 0) ] }.first(8)
  end

  def derive_network_status(critical_devices:, rogue_count:)
    reasons = []
    critical_offline = critical_devices.select do |device|
      ips = device.ip_addresses.to_a
      ips.any? && ips.none?(&:reachability_status_up?)
    end
    recent_severe = NetworkEvent.where(kind: [ :outage, :security ])
                                .where("created_at >= ?", 24.hours.ago).count

    reasons << "#{critical_offline.size} critical offline" if critical_offline.any?
    reasons << "#{recent_severe} severe events (24h)" if recent_severe.positive?

    status = reasons.any? ? :degraded : :operational
    reasons << "#{rogue_count} rogue devices" if status == :operational && rogue_count.positive?
    reasons << "All clear" if reasons.empty?
    [ status, reasons ]
  end
end
