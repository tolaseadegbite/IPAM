require "test_helper"

class BranchTest < ActiveSupport::TestCase
  test "cannot destroy branch with subnets" do
    branch = Branch.create!(name: "Subnet Owner", location: "Nowhere")
    subnets(:one).update!(branch: branch)

    assert_no_difference "Branch.count" do
      branch.destroy
    end
    assert branch.errors.any?
    assert_equal branch, subnets(:one).reload.branch
  end

  test "destroys cleanly without subnets or departments" do
    branch = Branch.create!(name: "Empty", location: "Nowhere")

    assert_difference "Branch.count", -1 do
      branch.destroy
    end
  end
end
