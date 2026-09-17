require "application_system_test_case"

class DeviceSubnetScopeTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
    @branch_one = branches(:one)
    @branch_two = branches(:two)
    subnets(:one).update!(branch: @branch_one)
    subnets(:two).update!(branch: @branch_two)
  end

  test "subnet picker follows the department branch" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit new_device_path
    select @branch_one.name, from: "branch_id"
    select departments(:one).name, from: "device_department_id"

    visible = evaluate_script(<<~JS)
      [...document.querySelectorAll('select[name^="subnet_filter"] option')]
        .filter((o) => o.value && !o.hidden).map((o) => o.text)
    JS
    assert_equal [subnets(:one).name], visible
  end

  test "existing cross-branch assignment stays selectable" do
    wan = subnets(:two)
    device = devices(:one)
    ip_addresses(:two).update!(device: device, status: :active)

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit edit_device_path(device)

    selected = evaluate_script(<<~JS)
      [...document.querySelectorAll('select[name^="subnet_filter"]')].map((s) => s.value)
    JS
    assert_includes selected, wan.id.to_s
  end
end
