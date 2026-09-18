require "application_system_test_case"

class ChatComposerTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  teardown do
    page.current_window.resize_to(1400, 1400)
  end

  test "composer uses icon picker without accordion" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    chat.messages.create!(role: "user", content: "Hello")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    assert_selector 'button[aria-label="Attach files"] svg'
    assert_no_selector "details[name='attachments']"
    assert_selector '[data-controller="dropzone"]'
  end

  test "long transcript fills viewport without page overflow" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    25.times do |i|
      chat.messages.create!(role: i.even? ? "user" : "assistant", content: "Message number #{i} with enough words to wrap.")
    end

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    [[1400, 900], [375, 812]].each do |width, height|
      page.current_window.resize_to(width, height)
      visit chat_path(chat)

      dims = evaluate_script(<<~JS)
        ({ x: document.scrollingElement.scrollWidth - window.innerWidth,
           y: document.scrollingElement.scrollHeight - window.innerHeight })
      JS
      assert dims["x"] <= 0, "horizontal overflow at #{width}x#{height}"
      assert dims["y"] <= 2, "page scrolls at #{width}x#{height} (#{dims["y"]}px over)"
    end
  end
end
