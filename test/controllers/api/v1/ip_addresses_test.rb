require "test_helper"

class ApiV1IpAddressesTest < ActionDispatch::IntegrationTest
  setup do
    _, raw = ApiToken.issue!(user: users(:lazaro_nixon), name: "spec")
    @headers = { "Authorization" => "Bearer #{raw}" }
  end

  test "index returns paginated addresses" do
    get api_v1_ip_addresses_url, headers: @headers
    assert_response :success

    body = response.parsed_body
    assert_kind_of Array, body["data"]
    assert_equal IpAddress.count, body.dig("meta", "count")
    assert_equal %w[id address status reachability_status last_seen_at subnet_id device_id].sort,
                 body["data"].first.keys.sort
  end

  test "index filters rogues" do
    get api_v1_ip_addresses_url(q: { rogue_only: true }), headers: @headers
    assert_response :success

    body = response.parsed_body
    assert_equal IpAddress.reachability_status_up.where(device_id: nil).count, body.dig("meta", "count")
  end

  test "index filters by device" do
    device = devices(:one)

    get api_v1_ip_addresses_url(q: { device_id_eq: device.id }), headers: @headers
    assert_response :success

    body = response.parsed_body
    assert_equal device.ip_addresses.count, body.dig("meta", "count")
    assert body["data"].all? { |ip| ip["device_id"] == device.id }
  end

  test "show returns address" do
    ip = ip_addresses(:one)

    get api_v1_ip_address_url(ip), headers: @headers
    assert_response :success
    assert_equal ip.address.to_s, response.parsed_body["address"]
  end
end
