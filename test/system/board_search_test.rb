require "application_system_test_case"

class BoardSearchTest < ApplicationSystemTestCase
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

  def focused_field
    page.driver.browser.switch_to.active_element
  end

  test "typing in board search keeps focus, filters, and clears in place" do
    sign_in
    visit board_path(@board)
    assert_text "Task One"

    click_on "Search & Filter"
    search = find_field("Search Tasks or Assets")
    search.fill_in with: "zzz-no-such-task"

    assert_text "No matching tasks"
    assert_no_text "Task One"
    # Input lives outside the results frame, so debounce resubmits
    # must never steal focus.
    assert_equal search.native, focused_field

    click_on "Clear"
    assert_text "Task One"
    assert_selector "[data-search-filter-target='filters']:not(.hidden)"
  end
end
