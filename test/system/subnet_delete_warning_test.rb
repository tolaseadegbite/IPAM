require "application_system_test_case"

class SubnetDeleteWarningTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "delete dialog names assigned impact" do
    subnet = subnets(:one)
    device = devices(:one)
    ip_addresses(:one).update!(device: device, status: :active)

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit subnet_path(subnet)
    click_on "Delete"

    assert_text "Also releases 1 assigned IP address"
    assert_text device.name
    assert_text "devices themselves are kept"
  end

  test "delete dialog stays quiet with no assignments" do
    subnet = Subnet.create!(name: "Quiet", network_address: "10.9.8.0/24", gateway: "10.9.8.1")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit subnet_path(subnet)
    click_on "Delete"

    assert_text "This will permanently delete this subnet"
    assert_no_text "Also releases"
  end
end
