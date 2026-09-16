require "application_system_test_case"

class AccountNavigationTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "reaching password and email settings from the user menu" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit root_path
    click_on @user.username
    click_on "Account"

    assert_text "Change password"
    click_on "Change password"
    assert_text "Change your password"

    visit account_path
    click_on "Change email address"
    assert_text "New email"
  end

  test "back buttons return to the previous page" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit account_path
    click_on "Activity log"
    assert_text "Activity Log"
    click_on "Back"
    assert_text "Login & verification"
  end

  test "masquerade shortcut stays parked" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit account_path
    assert_no_button "Sign in as last user"
  end
end
