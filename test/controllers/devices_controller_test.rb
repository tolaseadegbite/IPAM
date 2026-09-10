require "test_helper"

class DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show device" do
    get device_url(devices(:one))
    assert_response :success
  end

  test "should not show matching summary for blank filters" do
    # Cleared forms submit empty q values; the summary must only reflect
    # truly active filters.
    get devices_url(q: { name_cont: "", status_eq: "" })
    assert_response :success
    assert_select "p", text: /matching your filters/, count: 0
  end

  test "should not show matching summary for sort only" do
    get devices_url(q: { s: "name asc" })
    assert_response :success
    assert_select "p", text: /matching your filters/, count: 0
  end

  test "should show matching summary for real filters" do
    get devices_url(q: { name_cont: "Device One" })
    assert_response :success
    assert_select "p", text: /matching your filters/, count: 1
  end
end
