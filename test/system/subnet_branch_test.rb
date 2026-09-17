require "application_system_test_case"

class SubnetBranchTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "assigning a subnet to a branch from its page" do
    subnet = subnets(:one)
    branch = branches(:one)

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit edit_subnet_path(subnet)
    select branch.name, from: "Branch"
    click_on "Save Subnet"

    visit subnet_path(subnet)
    assert_link branch.name, href: branch_path(branch)

    visit branch_path(branch)
    assert_link subnet.name, href: subnet_path(subnet)
  end
end
