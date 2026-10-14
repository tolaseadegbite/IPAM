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

  test "create without frame falls back to redirect" do
    assert_difference "Device.count" do
      post devices_url(format: :turbo_stream), params: { device: { name: "Redirect Probe", device_type: "laptop",
                                                                   status: "active", department_id: departments(:one).id } }
    end
    assert_redirected_to device_url(Device.last)
  end

  test "create lands on show page" do
    post devices_url, params: { device: { name: "Show Probe", device_type: "laptop",
                                          status: "active", department_id: departments(:one).id } }
    assert_redirected_to device_url(Device.last)
  end

  test "update returns to index when edited from there" do
    get edit_device_url(devices(:one)), headers: { "Referer" => devices_url }
    patch device_url(devices(:one)), params: { device: { notes: "Origin probe" } }
    assert_redirected_to devices_url
  end

  test "update returns to show when edited from there" do
    get edit_device_url(devices(:one)), headers: { "Referer" => device_url(devices(:one)) }
    patch device_url(devices(:one)), params: { device: { notes: "Origin probe" } }
    assert_redirected_to device_url(devices(:one))
  end

  test "update falls back to show page without origin" do
    patch device_url(devices(:one)), params: { device: { notes: "Fallback probe" } }
    assert_redirected_to device_url(devices(:one))
  end

  test "update ignores hostile origin" do
    get edit_device_url(devices(:one)), headers: { "Referer" => "http://evil.example.com/x" }
    patch device_url(devices(:one)), params: { device: { notes: "Hostile probe" } }
    assert_redirected_to device_url(devices(:one))
  end

  test "interface_row html fallback returns to the form, not the index" do
    get interface_row_devices_url,
        headers: { "Referer" => new_device_url }

    assert_redirected_to new_device_url
  end

  test "interface_row html fallback uses index only without referrer" do
    get interface_row_devices_url

    assert_redirected_to devices_url
  end

  test "interface_row turbo stream appends a blank row" do
    get interface_row_devices_url,
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/turbo-stream action="append" target="interfaces-container"/, response.body)
    assert_match(/data-interface-row/, response.body)
  end
end
