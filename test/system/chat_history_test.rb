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
    # The pill is a viewport overlay: hidden initially and never
    # contributing to page layout.
    assert_selector "#jump_to_newest", visible: :hidden

    fill_in "message_content", with: "unsent draft"
    scroll_to_first_row

    within("#messages") { assert_text(/\bHistory message 1\b/, wait: 10) }
    assert_selector "#messages .message--user", count: 30
    assert_field "message_content", with: "unsent draft"

    # The no-jump invariant: the anchor message sits near the top where
    # the user parked — not pushed down-viewport nor snapped to bottom.
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

  test "short histories render fully" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    chat.messages.create!(role: "user", content: "Only message")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)

    assert_selector "#messages .message--user", count: 1
  end

  test "live arrivals reveal the pill and return on click" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    60.times { |i| chat.messages.create!(role: "user", content: "History message #{i + 1}") }

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    assert_selector "#messages .message--user", count: 25
    assert_selector "#jump_to_newest", visible: :hidden

    # Scroll into history, then simulate a live cable append arriving
    # while behind: the pill appears instead of snapping.
    scroll_to_first_row
    within("#messages") { assert_text(/\bHistory message 11\b/, wait: 10) }
    evaluate_script(<<~JS)
      (() => {
        const stream = document.createElement("turbo-stream");
        stream.setAttribute("action", "append");
        stream.setAttribute("target", "messages");
        stream.innerHTML = "<template><div id=\\"message_999999\\" class=\\"message message--user\\"><div class=\\"message__content\\">Live arrival</div></div></template>";
        const detail = {
          newStream: stream,
          render: (el) => Turbo.renderStreamMessage(el.outerHTML)
        };
        document.dispatchEvent(new CustomEvent("turbo:before-stream-render", {
          cancelable: true, detail
        }));
        // The controller wraps detail.render synchronously; invoking it
        // simulates Turbo completing the stream render.
        detail.render(stream);
      })()
    JS

    assert_selector "#jump_to_newest:not([hidden])", wait: 10
    assert_text "Live arrival"

    # Returning resets to the latest page (synthetic row was never saved).
    click_on "Jump to newest"
    assert_selector "#messages .message--user", count: 25, wait: 10
    assert_no_text "Live arrival"
    assert_selector "#jump_to_newest", visible: :hidden
  end

  test "dom stays bounded on long histories" do
    chat = Chat.create!(user: @user, model: "gemini-3.1-flash-lite")
    400.times { |i| chat.messages.create!(role: "user", content: "History message #{i + 1}") }

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit chat_path(chat)
    assert_selector "#messages .message--user", count: 25

    scroll_to_first_row
    within("#messages") { assert_text(/\bHistory message 351\b/, wait: 10) }

    row_count = evaluate_script("document.querySelectorAll('#messages [id^=\"message_\"]').length")

    assert_operator row_count, :<=, 330
  end

  private

  def scroll_to_first_row
    evaluate_script("window.__anchorId = document.querySelector('#messages .message--user').id")
    scroll_to(find("#messages .message--user", match: :first))
  end
end
