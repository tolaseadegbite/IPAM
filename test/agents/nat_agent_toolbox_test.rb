require "test_helper"

class NatAgentToolboxTest < ActiveSupport::TestCase
  test "build toolbox holds all twenty tools" do
    assert_equal 20, NatAgent.tools.call.size
  end

  test "plan toolbox holds only the twelve read tools" do
    plan = NatPlanAgent.tools.call

    assert_equal 12, plan.size
    assert_equal NatAgent::READ_TOOLS, plan
    assert_empty plan & NatAgent::WRITE_TOOLS
  end

  test "plan instructions demand approval without execution" do
    instructions = NatPlanAgent.instructions.is_a?(Proc) ? NatPlanAgent.instructions.call : NatPlanAgent.instructions
    # RubyLLM 2.0 returns structured instruction entries whose values may
    # be procs — resolve them before asserting on the text.
    text = Array(instructions).map { |entry|
      value = entry.is_a?(Hash) ? entry[:value] : entry
      value = value.call if value.is_a?(Proc)
      value.to_s
    }.join("\n")

    assert_includes text, "PLAN mode"
  end
end
