require "application_system_test_case"

class CardActivityTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
    @board = boards(:one)
    @card = @board.lists.first.cards.create!(title: "History probe")
    @card.users << @user
  end

  def sign_in
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"
  end

  test "task modal shows created and assigned history" do
    sign_in
    visit board_path(@board)
    click_on "History probe"
    assert_selector "dialog[open]"
    assert_text "created this task"
    assert_text "assigned #{@user.username}"
  end

  test "board feed shows latest activity with task title" do
    sign_in
    visit board_path(@board)
    assert_text "Recent activity"
    assert_selector 'details[data-controller="disclosure"]'
    find("summary", text: "Recent activity").click
    assert_selector "details[open]"
    assert_text "History probe"
    assert_text "assigned #{@user.username}"
  end
end
