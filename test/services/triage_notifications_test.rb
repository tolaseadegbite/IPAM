require "test_helper"

class TriageNotificationsTest < ActiveSupport::TestCase
  setup do
    @admin = users(:lazaro_nixon)
    assert @admin.admin?
    @device = devices(:one)
  end

  test "severe event notifies admins" do
    event = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized."
    )

    assert_difference("Noticed::Notification.count", 1) do
      TriageService.triage(event)
    end

    notification = Noticed::Notification.last
    assert_equal @admin, notification.recipient
    assert_equal @device, notification.event.record
  end

  test "flapping host notifies once until read" do
    first = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized."
    )
    TriageService.triage(first)

    repeat = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized again."
    )

    assert_no_difference("Noticed::Notification.count") do
      TriageService.triage(repeat)
    end
  end

  test "reading the notification re-arms the next flap" do
    first = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized."
    )
    TriageService.triage(first)
    @admin.notifications.mark_as_read

    repeat = NetworkEvent.create!(
      kind: :security, ip_address: "10.0.9.9", device: @device, message: "Seized again."
    )

    assert_difference("Noticed::Notification.count", 1) do
      TriageService.triage(repeat)
    end
  end

  test "info event notifies nobody" do
    event = NetworkEvent.create!(kind: :info, ip_address: "10.0.9.7", message: "Noted.")

    assert_no_difference("Noticed::Notification.count") do
      TriageService.triage(event)
    end
  end
end
