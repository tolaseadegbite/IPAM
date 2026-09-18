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
