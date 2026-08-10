require "test_helper"

class FlightdeckControllerTest < ActionDispatch::IntegrationTest
  test "should redirect unauthenticated users from flightdeck" do
    get "/flightdeck"
    assert_redirected_to "http://www.example.com/sign_in"
  end

  test "should bounce non-admin users from flightdeck" do
    user = users(:lazaro_nixon)
    user.update!(admin: false)
    sign_in_as(user)
    get "/flightdeck"
    assert_redirected_to "http://www.example.com/"
  end

  test "should allow admin access to flightdeck" do
    admin = users(:lazaro_nixon)
    admin.update!(admin: true)
    sign_in_as(admin)
    get "/flightdeck"
    assert_response :success
  end
end
