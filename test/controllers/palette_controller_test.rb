require "test_helper"

class PaletteControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should return navigation commands for blank query" do
    get palette_url

    assert_response :success
    labels = response.parsed_body.map { |r| r["label"] }
    assert_includes labels, "Go to Dashboard"
    assert_includes labels, "New Device"
  end

  test "should match commands and records by query" do
    get palette_url, params: { q: "subnet" }

    assert_response :success
    labels = response.parsed_body.map { |r| r["label"] }
    assert_includes labels, "Go to Subnets"
    assert response.parsed_body.any? { |r| r["icon"] == "network" && r["url"].start_with?("/subnets/") }
  end

  test "should require sign in" do
    delete session_url(users(:lazaro_nixon).sessions.last)

    get palette_url
    assert_redirected_to sign_in_url
  end
end
