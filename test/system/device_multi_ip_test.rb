require "application_system_test_case"

class DeviceMultiIpTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
    @corp = Subnet.create!(name: "Corporate", network_address: "192.168.13.0/24", gateway: "192.168.13.1")
    @alt = Subnet.create!(name: "Alt Corp", network_address: "192.168.30.0/24", gateway: "192.168.30.1")
    @y15 = Subnet.create!(name: "Yale 15", network_address: "172.15.242.0/24", gateway: "172.15.242.1")
    @y16 = Subnet.create!(name: "Yale 16", network_address: "172.16.242.0/24", gateway: "172.16.242.1")
    @radio = Subnet.create!(name: "Radio", network_address: "192.168.1.0/24", gateway: "192.168.1.1")
  end

  test "add ip rows across segments and save them all" do
    device = Device.create!(
      name: "Multi Box", device_type: :desktop, status: :active,
      department: departments(:one)
    )

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit edit_device_path(device)

    rows = interface_rows(1)
    rows[0].find("select[name^='subnet_filter']").select("Corporate")
    assert_selector "option", text: "192.168.13.10", wait: 10
    rows[0].find("select[name='device[ip_address_ids][]']").select("192.168.13.10")

    click_on "Add IP"
    rows = interface_rows(2)
    rows[1].find("select[name^='subnet_filter']").select("Yale 15")
    assert_selector "option", text: "172.15.242.10", wait: 10
    rows[1].find("select[name='device[ip_address_ids][]']").select("172.15.242.10")

    click_on "Save Device"
    assert_text "Device updated successfully", wait: 10
    assert_equal %w[172.15.242.10 192.168.13.10].sort,
                 device.reload.ip_addresses.map { |ip| ip.address.to_s }.sort
  end

  test "forbidden pairs are rejected with an explanation" do
    device = Device.create!(
      name: "Pair Box", device_type: :desktop, status: :active,
      department: departments(:one)
    )
    corp_ip = IpAddress.find_by!(address: "192.168.13.10")
    alt_ip = IpAddress.find_by!(address: "192.168.30.10")

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit edit_device_path(device)

    rows = interface_rows(1)
    rows[0].find("select[name^='subnet_filter']").select("Corporate")
    assert_selector "option", text: "192.168.13.10", wait: 10
    rows[0].find("select[name='device[ip_address_ids][]']").select("192.168.13.10")
    click_on "Add IP"
    rows = interface_rows(2)
    rows[1].find("select[name^='subnet_filter']").select("Alt Corp")
    assert_selector "option", text: "192.168.30.10", wait: 10
    rows[1].find("select[name='device[ip_address_ids][]']").select("192.168.30.10")

    click_on "Save Device"

    assert_text(/either side, not both/i, wait: 10)
    assert_nil alt_ip.reload.device_id
    assert_nil corp_ip.reload.device_id
  end

  test "add button caps at the policy maximum" do
    device = Device.create!(
      name: "Cap Box", device_type: :desktop, status: :active,
      department: departments(:one)
    )

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit edit_device_path(device)

    interface_rows(1)
    # Fixture subnets (2) + created (5) = 7 total, minus 2 exclusion
    # pairs = max 5 rows; one blank row renders initially.
    4.times do
      click_on "Add IP"
      interface_rows_minimum(2)
    end
    sleep 1

    assert_selector "#interfaces-container [data-interface-row]", count: 5
    assert_no_link "Add IP"
  end

  private

  # all() never waits — assert the count first (which retries), then grab.
  def interface_rows(count)
    assert_selector "#interfaces-container [data-interface-row]", count: count, wait: 10
    all("#interfaces-container [data-interface-row]")
  end

  def interface_rows_minimum(count)
    assert_selector "#interfaces-container [data-interface-row]", minimum: count, wait: 10
  end
end
