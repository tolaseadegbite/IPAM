require "test_helper"

class DepartmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show department" do
    get department_url(departments(:one))
    assert_response :success
  end
end
