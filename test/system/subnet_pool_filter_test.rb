require "application_system_test_case"

class SubnetPoolFilterTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "pool filter highlight follows the grid" do
    subnet = subnets(:one)

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit subnet_path(subnet)
    assert_selector 'a[aria-pressed="true"]', text: "All"

    click_on "Assigned"

    assert_selector 'a[aria-pressed="true"]', text: "Assigned"
    assert_equal "assigned",
                 evaluate_script("new URL(document.getElementById('ip_pool').src).searchParams.get('pool')")

    click_on "All"

    assert_selector 'a[aria-pressed="true"]', text: "All"
  end
end
