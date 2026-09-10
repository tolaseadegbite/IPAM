require "test_helper"

class PaletteControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

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

  test "should include the scan action with post method" do
    get palette_url, params: { q: "scan" }

    assert_response :success
    scan = response.parsed_body.find { |r| r["label"] == "Scan now" }
    assert_not_nil scan
    assert_equal "post", scan["method"]
  end

  test "scan action enqueues a network scan" do
    assert_enqueued_with(job: NetworkScanJob) do
      post scan_dashboard_url
    end

    assert_response :success
  end

  test "should require sign in" do
    delete session_url(users(:lazaro_nixon).sessions.last)

    get palette_url
    assert_redirected_to sign_in_url
  end
end
