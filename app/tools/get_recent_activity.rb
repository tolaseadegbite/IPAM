class GetRecentActivity < RubyLLM::Tool
  desc "Get recent network events and changes within a given time window"

  param :hours, type: "integer", desc: "Number of hours to look back (default: 24)", required: false

  def execute(hours: 24)
    since = hours.to_i.hours.ago

    {
      network_events: NetworkEvent.where("created_at > ?", since).recent.limit(20).map do |e|
        {
          kind: e.kind,
          message: e.message,
          device: e.device&.name,
          time: e.created_at.iso8601
        }
      end,
      recent_ip_changes: IpAddress.includes(:device)
                                   .where("updated_at > ? AND updated_at != created_at", since)
                                   .limit(20)
                                   .map do |ip|
        {
          address: ip.address.to_s,
          status: ip.status,
          reachability: ip.reachability_status,
          device: ip.device&.name,
          updated_at: ip.updated_at.iso8601
        }
      end
    }
  end
end
