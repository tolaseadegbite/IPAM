require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    sign_in_as @user
  end

  test "should get index scoped to current user" do
    other = User.create!(username: "otherone", email: "other@example.com",
                         password: "Sup3rSecretTemp!", verified: true)
    SecurityEventNotifier.with(record: nil, message: "Yours", kind: "info").deliver(@user)
    SecurityEventNotifier.with(record: nil, message: "Theirs", kind: "info").deliver(other)

    get notifications_url
    assert_response :success
    assert_select "#notifications_list", text: /Yours/
    assert_select "#notifications_list", text: /Theirs/, count: 0
  end

  test "should mark notification as read" do
    SecurityEventNotifier.with(record: nil, message: "Ping", kind: "info").deliver(@user)
    notification = @user.notifications.last

    patch notification_url(notification)

    assert_redirected_to notifications_url
    assert_predicate notification.reload, :read?
  end

  test "should render the header bell on the dashboard layout" do
    get root_url

    assert_response :success
    assert_select "#notification_bell", count: 1
  end

  test "should not touch another user's notification" do
    other = User.create!(username: "othertwo", email: "other2@example.com",
                         password: "Sup3rSecretTemp!", verified: true)
    SecurityEventNotifier.with(record: nil, message: "Theirs", kind: "info").deliver(other)
    foreign = other.notifications.last

    patch notification_url(foreign)

    assert_response :not_found
    assert_predicate foreign.reload, :unread?
  end
end
