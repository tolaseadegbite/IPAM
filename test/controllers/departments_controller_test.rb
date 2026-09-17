require "test_helper"

class DepartmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show department" do
    get department_url(departments(:one))
    assert_response :success
  end

  test "select_options answers frame requests with turbo stream" do
    get select_options_departments_url(branch_id: branches(:one).id),
        headers: { "Turbo-Frame" => "department_options_frame" }
    assert_response :success
    assert_match(/turbo-stream action="update" target="department_options_frame"/, response.body)
  end

  test "select_options renders bare partial without frame" do
    get select_options_departments_url(branch_id: branches(:one).id)
    assert_response :success
    assert_no_match(/turbo-stream/, response.body)
  end
end
