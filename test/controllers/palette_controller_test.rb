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
    assert_includes labels, "Go to Dashboard (Ctrl + Shift + Y)"
    assert_includes labels, "New Device"
    assert_includes labels, "Go to Employees (Ctrl + Shift + E)"
    assert_includes labels, "Go to Departments"
    assert_includes labels, "New Employee"
    assert_includes labels, "Go to History"
    assert_includes labels, "Go to IP Addresses (Ctrl + Shift + U)"
    assert_includes labels, "Go to Operations (Ctrl + Shift + K)"
  end

  test "should match people, places, and tasks by query" do
    get palette_url, params: { q: "Headquarters" }

    assert_response :success
    branches = response.parsed_body.select { |r| r["section"] == "Places" }
    assert branches.any? { |r| r["url"].start_with?("/branches/") }

    get palette_url, params: { q: "Engineering" }

    assert_response :success
    departments = response.parsed_body.select { |r| r["section"] == "Places" }
    assert departments.any? { |r| r["url"].start_with?("/departments/") }
  end

  test "should match employees by name" do
    get palette_url, params: { q: "MyString" }

    assert_response :success
    employees = response.parsed_body.select { |r| r["section"] == "People" }
    assert employees.any? { |r| r["url"].start_with?("/employees/") }
  end

  test "should match ip addresses and link tasks to boards" do
    get palette_url, params: { q: "10.0.1" }

    assert_response :success
    assert response.parsed_body.any? { |r| r["section"] == "Network" && r["url"].start_with?("/ip_addresses/") }

    get palette_url, params: { q: "Task One" }
    assert_response :success
    tasks = response.parsed_body.select { |r| r["section"] == "Tasks" }
    assert_not_empty tasks
    assert tasks.all? { |r| r["url"].start_with?("/boards") }
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
