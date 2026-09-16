require "application_system_test_case"

class PopoverScrollTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "open popover closes when the page scrolls" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"

    visit root_path
    assert_text "Needs attention", wait: 10
    click_on "Theme"
    assert_selector ".popover:popover-open", text: "Osaka Jade"

    evaluate_script("window.scrollBy(0, 400)")
    sleep 0.5

    assert_no_selector ".popover:popover-open"
  end
end
