require "test_helper"

class EmployeesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show employee" do
    get employee_url(employees(:one))
    assert_response :success
  end

  test "select_options answers frame requests with turbo stream" do
    get select_options_employees_url(department_id: departments(:one).id),
        headers: { "Turbo-Frame" => "employee_options_frame" }
    assert_response :success
    assert_match(/turbo-stream action="update" target="employee_options_frame"/, response.body)
  end
end
