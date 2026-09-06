require "test_helper"

class VersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should get index" do
    get versions_index_url
    assert_response :success
  end
end
