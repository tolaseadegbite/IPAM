require "application_system_test_case"

class ChatModeToggleTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "toggling plan and build persists" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    chat.messages.create!(role: "user", content: "Will this work?")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    assert_selector 'button[aria-pressed="true"]', text: "Plan"

    click_on "Build"
    assert_selector 'button[aria-pressed="true"]', text: "Build"
    assert chat.reload.build_mode?

    refresh
    assert_selector 'button[aria-pressed="true"]', text: "Build"

    click_on "Plan"
    assert_selector 'button[aria-pressed="true"]', text: "Plan"
    assert chat.reload.plan_mode?
  end

    test "escape key flips modes" do    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    chat.messages.create!(role: "user", content: "Will this work?")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    assert_selector 'button[aria-pressed="true"]', text: "Plan"

    find("body").send_keys(:escape)
    assert_selector 'button[aria-pressed="true"]', text: "Build"
    assert chat.reload.build_mode?

    find("body").send_keys(:escape)
    assert_selector 'button[aria-pressed="true"]', text: "Plan"
    assert chat.reload.plan_mode?
  end

  test "mode toggle lives in the message form and bubbles stay readable" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    chat.messages.create!(role: "user", content: "Will this work?")
    chat.messages.create!(role: "assistant", content: "Yes, working.")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    # Toggle is the first item of the composer toolbar row, inside the
    # message form. Pills are plain buttons (never nested forms), so the
    # form contains zero nested <form> elements.
    assert_selector "form#new_message [role='group'][aria-label='Assistant mode']"
    assert_no_selector "form#new_message form"
    assert_selector "form#new_message [role='group'][aria-label='Assistant mode'] button[type='button']", count: 2

    widths = evaluate_script(<<~JS)
      ({
        assistant: getComputedStyle(document.querySelector(".message--assistant")).maxWidth,
        user: getComputedStyle(document.querySelector(".message--user")).maxWidth
      })
    JS
    assert_equal "768px", widths["assistant"]
    assert_equal "75%", widths["user"]
  end

  test "new chat offers starting mode" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit new_chat_path
    assert_checked_field "chat_mode_plan"
    assert_unchecked_field "chat_mode_build"

    find("#chat_model option[value='gemini-3.1-flash-lite']").select_option
    within("[aria-label='Starting mode']") { find("label", text: "Build").click }
    fill_in "Your question:", with: "Is anyone there?"
    click_on "Start new chat"

    # Chat creation persists agent configuration — allow for a slow store.
    assert_selector 'button[aria-pressed="true"]', text: "Build", wait: 10
  end
end
