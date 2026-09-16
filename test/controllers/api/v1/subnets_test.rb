require "test_helper"

class ApiV1SubnetsTest < ActionDispatch::IntegrationTest
  setup do
    _, raw = ApiToken.issue!(user: users(:lazaro_nixon), name: "spec")
    @headers = { "Authorization" => "Bearer #{raw}" }
  end

  test "index returns paginated subnets" do
    get api_v1_subnets_url, headers: @headers
    assert_response :success

    body = response.parsed_body
    assert_kind_of Array, body["data"]
    assert_equal Subnet.count, body.dig("meta", "count")
    assert_equal %w[id name network_address gateway vlan_id].sort, body["data"].first.keys.sort
  end

  test "show returns subnet with utilization" do
    subnet = subnets(:one)

    get api_v1_subnet_url(subnet), headers: @headers
    assert_response :success

    body = response.parsed_body
    assert_equal subnet.name, body["name"]
    assert_equal subnet.network_address.to_s, body["network_address"]
    assert body.key?("total_ips")
    assert body.key?("used_ips")
  end

  test "show 404s unknown subnet" do
    get api_v1_subnet_url(0), headers: @headers
    assert_response :not_found
  end
end
