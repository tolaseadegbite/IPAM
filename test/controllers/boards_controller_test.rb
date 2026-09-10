require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
    @board = boards(:one)
  end

  test "should show board" do
    get board_url(@board)
    assert_response :success
  end

  test "should leave mobile clearance below the activity feed" do
    get board_url(@board)
    assert_response :success
    assert_select "div.h-10.lg\\:hidden", count: 1
  end

  test "should render boot assets on board show" do
    # The board page must ship its importmap + stylesheet tags.
    # (csrf/csp metas are intentionally absent here: test env disables
    # forgery protection and no CSP policy is configured.)
    get board_url(@board)
    assert_response :success
    assert_includes response.body, "importmap"
    assert_includes response.body, "tailwind"
  end

  test "should not show active filters for blank search" do
    get board_url(@board, q: { priority_eq: "" })
    assert_response :success
    assert_select "span", text: "Active filters:", count: 0
  end

  test "should show active filters for real search" do
    get board_url(@board, q: { priority_eq: "1" })
    assert_response :success
    assert_select "span", text: "Active filters:", count: 1
  end
end
