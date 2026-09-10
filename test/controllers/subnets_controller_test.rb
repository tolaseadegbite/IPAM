require "test_helper"

class SubnetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show subnet" do
    get subnet_url(subnets(:one))
    assert_response :success
  end
end
