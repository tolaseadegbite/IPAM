require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "new chats start in plan mode" do
    chat = users(:lazaro_nixon).chats.create!(model: "gemini-3.1-flash-lite")

    assert chat.plan_mode?
    assert_equal "plan", chat.reload.mode
  end

  test "mode flips both ways" do
    chat = users(:lazaro_nixon).chats.create!(model: "gemini-3.1-flash-lite")

    chat.update!(mode: :build)
    assert chat.build_mode?

    chat.update!(mode: :plan)
    assert chat.plan_mode?
  end
end
