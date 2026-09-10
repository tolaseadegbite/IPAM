require "test_helper"

class EmployeesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show employee" do
    get employee_url(employees(:one))
    assert_response :success
  end
end
