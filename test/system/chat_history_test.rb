require "application_system_test_case"

class ChatHistoryTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "scrolling up loads older messages without losing place or draft" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    30.times { |i| chat.messages.create!(role: "user", content: "History message #{i + 1}") }

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    assert_selector "#messages .message--user", count: 25
    assert_selector "#history_sentinel"
    # NOTE: scoped to the list (the header quotes message 1), with a word
    # boundary so messages 10-19 do not match.
    within("#messages") { assert_no_text(/\bHistory message 1\b/) }

    fill_in "message_content", with: "unsent draft"
    evaluate_script("window.__anchorId = document.querySelector('#messages .message--user').id")
    scroll_to(find("#history_sentinel"))

    within("#messages") { assert_text(/\bHistory message 1\b/, wait: 10) }
    assert_selector "#messages .message--user", count: 30
    assert_no_selector "#history_sentinel"
    assert_field "message_content", with: "unsent draft"

    # The no-jump invariant: after older content lands above, the anchor
    # message must sit near the top where the user parked — not pushed
    # ~1700px down-viewport (the jump-to-top bug) nor snapped to bottom.
    after_top = evaluate_script(<<~JS)
      (() => {
        const list = document.querySelector('#messages');
        const anchor = document.getElementById(window.__anchorId);
        return anchor.getBoundingClientRect().top - list.getBoundingClientRect().top;
      })()
    JS

    assert_operator after_top, :>, -50
    assert_operator after_top, :<, 300
  end

  test "short histories render fully with no sentinel" do    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    chat.messages.create!(role: "user", content: "Only message")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)

    assert_selector "#messages .message--user", count: 1
    assert_no_selector "#history_sentinel"
  end

  test "one scroll gesture loads exactly one window" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    60.times { |i| chat.messages.create!(role: "user", content: "History message #{i + 1}") }
    ids = chat.messages.order(:id).pluck(:id)

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    assert_selector "#messages .message--user", count: 25
    assert_selector "#history_sentinel[data-oldest-id='#{ids[-25]}']"

    # One gesture: exactly one older window loads (oldest drops by 25),
    # even though history remains below it.
    scroll_to(find("#history_sentinel"))
    assert_selector "#messages .message--user", count: 50, wait: 10
    sleep 2
    assert_selector "#history_sentinel[data-oldest-id='#{ids[-50]}']"

    # Scroll away and back: the second visit loads the final window.
    evaluate_script("document.querySelector('#messages').scrollTop = document.querySelector('#messages').scrollHeight")
    sleep 1
    scroll_to(find("#history_sentinel"))
    assert_selector "#messages .message--user", count: 60, wait: 10
    assert_no_selector "#history_sentinel"
  end
end
