require "test_helper"

class ApiV1AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    _, @raw = ApiToken.issue!(user: users(:lazaro_nixon), name: "spec")
  end

  test "rejects missing token" do
    get api_v1_subnets_url
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")
  end

  test "rejects bogus token" do
    get api_v1_subnets_url, headers: { "Authorization" => "Bearer not-a-real-token" }
    assert_response :unauthorized
  end

  test "rejects expired token" do
    _, raw = ApiToken.issue!(user: users(:lazaro_nixon), name: "old", expires_at: 1.hour.ago)

    get api_v1_subnets_url, headers: { "Authorization" => "Bearer #{raw}" }
    assert_response :unauthorized
  end

  test "accepts valid bearer token" do
    get api_v1_subnets_url, headers: { "Authorization" => "Bearer #{@raw}" }
    assert_response :success
  end
end
