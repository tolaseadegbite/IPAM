require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
    @chat = users(:lazaro_nixon).chats.create!(model: "gemini-3.1-flash-lite")
  end

  test "shows chat" do
    get chat_url(@chat)
    assert_response :success
  end

  test "show renders newest window with sentinel when history overflows" do
    30.times { |i| @chat.messages.create!(role: "user", content: "History message #{i + 1}") }

    get chat_url(@chat)

    assert_response :success
    # Skeleton shares the .message class, so count user bubbles precisely.
    assert_select "#messages .message--user", count: 25
    assert_select "#history_sentinel"
  end

  test "show renders everything with no sentinel for short histories" do
    @chat.messages.create!(role: "user", content: "Only message")

    get chat_url(@chat)

    assert_response :success
    assert_select "#messages .message--user", count: 1
    assert_select "#history_sentinel", count: 0
  end

  test "before_id turbo stream prepends the older window" do
    30.times { |i| @chat.messages.create!(role: "user", content: "History message #{i + 1}") }
    # NOTE: minimum ignores limit — resolve the window edge in Ruby.
    # reorder (not order): the messages association sorts ascending by
    # default, which an appended order can never override.
    oldest_loaded = @chat.messages.reorder(id: :desc).limit(25).pluck(:id).min

    get chat_url(@chat, before_id: oldest_loaded),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/action="prepend"/, response.body)
    assert_match(/History message 1</, response.body)
    # Only five older messages exist with nothing below them, so the
    # exhausted window drops the sentinel instead of replacing it.
    assert_match(/action="remove"/, response.body)
  end

  test "before_id turbo stream refreshes the sentinel mid-history" do
    60.times { |i| @chat.messages.create!(role: "user", content: "History message #{i + 1}") }
    edge = @chat.messages.reorder(id: :desc).limit(25).pluck(:id).min
    next_oldest = @chat.messages.where("messages.id < ?", edge).reorder(id: :desc).limit(25).pluck(:id).min

    get chat_url(@chat, before_id: edge),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/action="prepend"/, response.body)
    assert_match(/data-oldest-id="#{next_oldest}"/, response.body)
  end

  test "before_id turbo stream drops the sentinel when exhausted" do
    3.times { |i| @chat.messages.create!(role: "user", content: "History message #{i + 1}") }
    oldest = @chat.messages.minimum(:id)

    get chat_url(@chat, before_id: oldest),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/action="remove"/, response.body)
  end

  test "before_id over html redirects to the clean chat page" do
    get chat_url(@chat, before_id: 123)

    assert_redirected_to chat_url(@chat)
  end

  test "flips chat to build mode" do
    patch chat_url(@chat), params: { chat: { mode: "build" } }
    assert_redirected_to chat_url(@chat)
    assert @chat.reload.build_mode?
  end

  test "flips chat back to plan mode" do
    @chat.update!(mode: :build)

    patch chat_url(@chat), params: { chat: { mode: "plan" } }
    assert_redirected_to chat_url(@chat)
    assert @chat.reload.plan_mode?
  end

  test "rejects unknown mode" do
    patch chat_url(@chat), params: { chat: { mode: "turbo" } }
    assert_redirected_to chat_url(@chat)
    assert @chat.reload.plan_mode?
  end

  test "cannot flip another users chat" do
    other = User.create!(username: "otherone", email: "other@example.com",
                         password: "Sup3rSecretTemp!", verified: true)
    chat = other.chats.create!(model: "gemini-3.1-flash-lite")

    patch chat_url(chat), params: { chat: { mode: "build" } }
    assert_response :not_found
    assert chat.reload.plan_mode?
  end

  test "requires sign in" do
    delete session_url(users(:lazaro_nixon).sessions.last)

    patch chat_url(@chat), params: { chat: { mode: "build" } }
    assert_redirected_to sign_in_url
  end

  test "creates chat in plan mode by default" do
    assert_difference "Chat.count" do
      post chats_url, params: { chat: { prompt: "Hello there", model: "gemini-3.1-flash-lite" } }
    end
    assert Chat.last.plan_mode?
  end

  test "creates chat in build mode when requested" do
    post chats_url, params: { chat: { prompt: "Hello there", model: "gemini-3.1-flash-lite", mode: "build" } }
    assert Chat.last.build_mode?
  end

  test "ignores unknown mode on create" do
    post chats_url, params: { chat: { prompt: "Hello there", model: "gemini-3.1-flash-lite", mode: "turbo" } }
    assert Chat.last.plan_mode?
  end
end
