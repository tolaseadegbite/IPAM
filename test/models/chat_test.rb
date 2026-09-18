require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "new chats start in plan mode" do
    chat = users(:lazaro_nixon).chats.create!(model: models(:gemini_flash))

    assert chat.plan_mode?
    assert_equal "plan", chat.reload.mode
  end

  test "mode flips both ways" do
    chat = users(:lazaro_nixon).chats.create!(model: models(:gemini_flash))

    chat.update!(mode: :build)
    assert chat.build_mode?

    chat.update!(mode: :plan)
    assert chat.plan_mode?
  end
end
