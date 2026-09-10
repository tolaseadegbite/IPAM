class DeliveryMethods::TurboStream < ApplicationDeliveryMethod
  # Renders straight into the recipient's header bell + dropdown over
  # their personal stream. No client JavaScript: Turbo applies the
  # swapped HTML, consistent with every other live surface in the app.
  def deliver
    return unless recipient.is_a?(User)

    broadcast_replace_to(
      "notifications_#{recipient.id}",
      target: "notification_bell",
      partial: "notifications/bell",
      locals: { user: recipient }
    )
    broadcast_prepend_to(
      "notifications_#{recipient.id}",
      target: "notifications_list",
      partial: "notifications/notification",
      locals: { notification: notification }
    )
  end
end
