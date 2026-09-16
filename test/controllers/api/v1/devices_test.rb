require "test_helper"

class ApiV1DevicesTest < ActionDispatch::IntegrationTest
  setup do
    _, raw = ApiToken.issue!(user: users(:lazaro_nixon), name: "spec")
    @headers = { "Authorization" => "Bearer #{raw}" }
  end

  test "index returns paginated devices" do
    get api_v1_devices_url, headers: @headers
    assert_response :success

    body = response.parsed_body
    assert_kind_of Array, body["data"]
    assert_equal Device.count, body.dig("meta", "count")
  end

  test "show returns device with addresses" do
    device = devices(:one)

    get api_v1_device_url(device), headers: @headers
    assert_response :success

    body = response.parsed_body
    assert_equal device.name, body["name"]
    assert_kind_of Array, body["ip_addresses"]
  end
end
