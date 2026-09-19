require "test_helper"

class NatAgentToolboxTest < ActiveSupport::TestCase
  test "build toolbox holds all twenty-four tools" do
    assert_equal 24, NatAgent.tools.call.size
  end

  test "plan toolbox holds only the thirteen read tools" do
    plan = NatPlanAgent.tools.call

    assert_equal 13, plan.size
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

  test "base instructions separate allocation status from liveness" do
    text = NatAgent::BASE_INSTRUCTIONS

    assert_includes text, "reachability_status"
    assert_includes text, "reachable_ips"
  end

  test "base instructions collect required fields and confirm subnets" do
    text = NatAgent::BASE_INSTRUCTIONS

    assert_includes text, "missing required fields"
    assert_includes text, "branch_name"
    assert_includes text, "gateway"
  end

  test "base instructions cover scans, bulk branch, and update ask-first" do
    text = NatAgent::BASE_INSTRUCTIONS

    assert_includes text, "ScanSubnet"
    assert_includes text, "unprompted"
    assert_includes text, "top-level branch_name"
    assert_includes text, "which fields to update"
  end
end
