require "application_system_test_case"

class ModelsRefreshButtonTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "admin sees refresh button on chats index" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chats_path

    assert_button "Refresh Models"
  end

  test "non-admin has no refresh button on chats index" do
    @user.update!(admin: false)

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chats_path

    assert_no_button "Refresh Models"
  end

  test "new chat offers 3.8 flash as the default model" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit new_chat_path

    assert_selector "#chat_model option[value='']", text: /3\.8 Flash/
  end
end
