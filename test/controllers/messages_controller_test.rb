require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
    @chat = users(:lazaro_nixon).chats.create!(model: "gemini-3.1-flash-lite")
    @messages = []
    30.times { |i| @messages << @chat.messages.create!(role: "user", content: "History message #{i + 1}") }
  end

  test "index returns the last page by default" do
    get chat_messages_url(@chat)

    assert_response :success
    ensure_messages_present(*@messages.last(25))
    ensure_messages_not_present(*@messages.first(5))
  end

  test "index returns a page before the specified message" do
    edge = @messages.last(25).first

    get chat_messages_url(@chat, before: edge.id)

    assert_response :success
    ensure_messages_present(*@messages.first(5))
    ensure_messages_not_present(edge, *@messages.last(24))
  end

  test "index returns a page after the specified message" do
    get chat_messages_url(@chat, after: @messages.first.id)

    assert_response :success
    ensure_messages_present(*@messages[1, 25])
    ensure_messages_not_present(@messages.first, *@messages.last(4))
  end

  test "index returns no content when the window is empty" do
    get chat_messages_url(@chat, before: @messages.first.id)

    assert_response :no_content
  end

  test "index scopes windows to its own chat" do
    other = users(:lazaro_nixon).chats.create!(model: "gemini-3.1-flash-lite")
    foreign = other.messages.create!(role: "user", content: "Other chat message")

    get chat_messages_url(@chat)

    assert_response :success
    ensure_messages_not_present(foreign)
  end

  private

  def ensure_messages_present(*messages)
    messages.each do |message|
      assert_select "#message_#{message.id}", count: 1
    end
  end

  def ensure_messages_not_present(*messages)
    messages.each do |message|
      assert_select "#message_#{message.id}", count: 0
    end
  end
end
