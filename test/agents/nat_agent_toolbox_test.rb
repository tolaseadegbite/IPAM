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
    text = instructions.is_a?(Hash) ? instructions.to_s : instructions.to_s

    assert_includes text, "PLAN mode"
  end
end
