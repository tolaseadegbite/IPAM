module DashboardData
  extend ActiveSupport::Concern

  # Palette keys, not hexes: chart_controller.js resolves them against the
  # live theme (canvas can't use CSS var() directly). Defaults live in
  # :root as --chart-*; per-theme overrides ride on html[data-theme].
  TREND_COLORS = {
    "info" => "--chart-info",
    "drift" => "--chart-drift",
    "outage" => "--chart-outage",
    "security" => "--chart-security"
  }.freeze

  # One pluck, four bucketings. Sub-day ranges use rolling windows aligned
  # to the hour / 5 minutes; day ranges use calendar days (as before).
  def build_events_trends(now = Time.current)
    rows = NetworkEvent.where("created_at >= ?", 13.days.ago.beginning_of_day)
                       .pluck(:created_at, :kind)
    hour = now.beginning_of_hour
    five = now.change(min: now.min - (now.min % 5), sec: 0)

    {
      "1h" => trend_dataset(rows, 11.downto(0).map { |n| five - n * 5.minutes }, "%H:%M", now),
      "24h" => trend_dataset(rows, 23.downto(0).map { |n| hour - n * 1.hour }, "%H:00", now),
      "7d" => trend_dataset(rows, 6.downto(0).map { |n| n.days.ago.beginning_of_day }, "%b %-d", now),
      "14d" => trend_dataset(rows, 13.downto(0).map { |n| n.days.ago.beginning_of_day }, "%b %-d", now)
    }
  end

  # Shared by DashboardsController and NetworkReconService so the live
  # dashboard and scan broadcasts always render the same partial shape.
  # URL + date helpers go through global proxies so this works outside
  # of a request (jobs/services) as well as inside controllers.
  def trend_dataset(rows, starts, label_format, now)
    bounds = starts + [ now ]
    counts = Hash.new { |h, k| h[k] = Hash.new(0) }
    rows.each do |at, kind|
      idx = bounds.bsearch_index { |b| b > at }
      next if idx.nil? || idx.zero?

      counts[idx - 1][kind] += 1
    end

    {
      labels: starts.map { |s| s.strftime(label_format) },
      datasets: NetworkEvent.kinds.keys.map do |kind|
        {
          label: kind.humanize,
          data: starts.each_index.map { |i| counts[i][kind] },
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
        full_title: event.message.to_s,
        subtitle: [ event.ip_address, event.device&.name ].compact.join(" · "),
        path: event.device ? routes.device_path(event.device) : nil,
        age: event.created_at,
        row_id: "attention-event-#{event.id}"
      }
    end

    critical_devices.each do |device|
      ips = device.ip_addresses.to_a
      next if ips.empty? || ips.any?(&:reachability_status_up?)

      items << {
        severity: :critical,
        icon: "monitor-x",
        title: "#{device.name} is offline",
        full_title: "#{device.name} is offline",
        subtitle: ips.first ? "Critical · #{ips.first.address}" : "Critical · no IP assigned",
        path: routes.device_path(device),
        age: ips.filter_map(&:last_seen_at).max,
        row_id: "attention-device-#{device.id}",
        action: { label: "Open task", path: routes.new_card_path(referenceable_type: "Device", referenceable_id: device.id), modal: true }
      }
    end

    rogue_devices.each do |ip|
      items << {
        severity: :high,
        icon: "triangle-alert",
        title: "Rogue device at #{ip.address}",
        full_title: "Rogue device at #{ip.address}",
        subtitle: ip.subnet&.name,
        path: routes.ip_address_path(ip),
        age: ip.last_seen_at,
        row_id: "attention-ip-#{ip.id}",
        action: { label: "Register", path: routes.edit_ip_address_path(ip), modal: true }
      }
    end

    ghost_assets.each do |ip|
      items << {
        severity: :medium,
        icon: "history",
        title: "Reclaim #{ip.device&.name || ip.address}",
        full_title: "Reclaim #{ip.device&.name || ip.address}",
        subtitle: ip.last_seen_at ? "Unseen #{time_ago.time_ago_in_words(ip.last_seen_at)}" : "Ghost asset",
        path: routes.ip_address_path(ip),
        age: ip.last_seen_at,
        row_id: "attention-ip-#{ip.id}",
        action: { label: "Reclaim", path: routes.reclaim_ip_address_path(ip), method: :patch }
      }
    end

    high_priority_tasks.each do |card|
      items << {
        severity: :medium,
        icon: "kanban",
        title: card.title,
        full_title: card.title,
        subtitle: card.list&.name,
        path: routes.edit_card_path(card),
        modal: true,
        age: card.created_at,
        row_id: "attention-card-#{card.id}"
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
