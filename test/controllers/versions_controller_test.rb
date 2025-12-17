require "test_helper"

class VersionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get versions_index_url
    assert_response :success
  end
end
