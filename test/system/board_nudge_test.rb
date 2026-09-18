require "application_system_test_case"

# Column reorder persistence, driven through the deterministic nudge
# buttons (true browser input, full PATCH loop). Pointer-drag gestures
# cannot be driven reliably headless (synthetic press sequences never
# reach pointer/mouse listeners), so drag behavior is verified manually;
# the drop path it shares with nudge (save/revert) is covered here.
class BoardNudgeTest < ApplicationSystemTestCase
  teardown do
    page.current_window.resize_to(1400, 1400)
  end

  setup do
    @user = users(:lazaro_nixon)
    @board = boards(:one)
  end

  def sign_in
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"
  end

  def column_ids
    all("#lists-container > div[data-list-id]").map { |el| el["data-list-id"].to_i }
  end

  test "nudge buttons reorder columns deterministically" do
    sign_in
    @board.lists.create!(name: "Alpha")
    visit board_path(@board)

    before = column_ids
    assert_equal 2, before.size

    find("#lists-container > div:first-child button[aria-label='Move column right']").click
    sleep 1 # allow the PATCH to land before reloading

    visit board_path(@board) # reload proves server persistence
    assert_equal [ before[1], before[0] ], column_ids
  end
end
