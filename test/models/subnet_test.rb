require "test_helper"

class SubnetTest < ActiveSupport::TestCase
  test "belongs to branch optionally" do
    subnet = subnets(:one)

    assert_nil subnet.branch

    subnet.update!(branch: branches(:one))
    assert_equal branches(:one), subnet.reload.branch
  end
end
