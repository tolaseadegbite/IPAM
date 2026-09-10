# Fan-out for severe network findings. Realtime only (Turbo Stream into
# the header bell); email is a future `deliver_by :email, wait:, unless:`
# addition, not a rework. Triggered next to triage-card creation so the
# two can never diverge.
class SecurityEventNotifier < Noticed::Event
  deliver_by :turbo_stream, class: "DeliveryMethods::TurboStream"

  notification_methods do
    def message
      params[:message]
    end

    def asset_name
      record.respond_to?(:name) ? record.name : record.to_s
    end

    def url
      case record
      when Device then Rails.application.routes.url_helpers.device_path(record)
      when IpAddress then Rails.application.routes.url_helpers.ip_address_path(record)
      else Rails.application.routes.url_helpers.dashboard_path
      end
    end
  end
end
