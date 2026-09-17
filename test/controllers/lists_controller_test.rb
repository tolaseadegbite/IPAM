require "test_helper"

class ListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
    @board = boards(:one)
  end

  test "select_options answers frame requests with turbo stream" do
    get select_options_lists_url(board_id: @board.id),
        headers: { "Turbo-Frame" => "list_options_frame" }
    assert_response :success
    assert_match(/turbo-stream action="update" target="list_options_frame"/, response.body)
  end

  test "should reorder list within board" do
    first = lists(:one)
    second = @board.lists.create!(name: "Second")
    assert_equal [ first.id, second.id ], @board.lists.order(:position).ids

    patch move_list_url(first), params: { position: 2 }
    assert_response :success

    assert_equal [ second.id, first.id ], @board.lists.order(:position).ids
  end

  test "should reject move with invalid position" do
    list = lists(:one)

    patch move_list_url(list), params: { position: 0 }
    assert_response :unprocessable_entity

    assert_equal 1, list.reload.position
  end
end
