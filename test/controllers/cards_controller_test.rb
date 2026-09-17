require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
    @board = boards(:one)
  end

  test "select_assets answers frame requests with turbo stream" do
    get select_assets_cards_url(asset_type: "Device"),
        headers: { "Turbo-Frame" => "asset_options_frame" }
    assert_response :success
    assert_match(/turbo-stream action="update" target="asset_options_frame"/, response.body)
  end

  test "should move card between lists" do
    card = cards(:one)
    target = @board.lists.create!(name: "Target")

    patch move_card_url(card), params: { list_id: target.id, position: 1 }
    assert_response :success

    assert_equal target.id, card.reload.list_id
    assert_equal 1, card.position
  end

  test "should reject move to nonexistent list" do
    card = cards(:one)
    list_id = card.list_id

    patch move_card_url(card), params: { list_id: -1, position: 1 }
    assert_response :unprocessable_entity

    assert_equal list_id, card.reload.list_id
  end

  test "should show task history on edit" do
    card = cards(:one)
    card.update!(title: "Renamed for history")

    get edit_card_url(card)
    assert_response :success
    assert_select "h3", text: "Task History"
    assert_includes response.body, "edited title"
  end

  test "should reject duplicate assignees on update" do
    card = cards(:one)
    user_id = users(:lazaro_nixon).id

    patch card_url(card), params: { card: { title: card.title, user_ids: [ user_id, user_id ] } }
    assert_response :unprocessable_entity
  end

  test "should include non-active devices in asset picker" do
    device = devices(:one)
    device.update!(status: :retired, ip_addresses: [])

    get select_assets_cards_url(asset_type: "Device")
    assert_response :success
    assert_includes response.body, device.name
  end
end
