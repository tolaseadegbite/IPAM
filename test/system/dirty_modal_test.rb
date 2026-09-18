require "application_system_test_case"

class DirtyModalTest < ApplicationSystemTestCase
  teardown do
    page.current_window.resize_to(1400, 1400)
  end

  setup do
    @user = users(:lazaro_nixon)
  end

  def sign_in
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"
  end

  test "cancel keeps a clean modal closing silently" do
    sign_in
    visit subnet_path(subnets(:one))
    click_on "Edit", match: :first
    assert_selector "dialog[open]"
    click_on "Cancel"
    assert_no_selector "dialog[open]"
  end

  test "cancel on a dirty modal asks first, discard closes" do
    sign_in
    visit subnet_path(subnets(:one))
    click_on "Edit", match: :first
    assert_selector "dialog[open]"
    fill_in "Subnet Name", with: "Changed name"
    click_on "Cancel"
    assert_text "You have unsaved changes."
    assert_selector "dialog[open]"
    click_on "Discard"
    assert_no_selector "dialog[open]"
  end

  test "reset clears filters without collapsing the panel" do
    sign_in
    visit devices_path
    click_on "Search & Filter"
    fill_in "Keyword", with: "zzz-no-such-device"
    assert_text "No devices found"
    click_on "Clear"
    assert_text "Device One"
    assert_selector "[data-search-filter-target='filters']:not(.hidden)"
  end

  test "clear all dismisses pills without stale summary or collapsing the panel" do
    sign_in
    visit devices_path
    click_on "Search & Filter"
    fill_in "Keyword", with: "zzz-no-such-device"
    assert_text "No devices found"
    assert_text "matching your filters"
    click_on "Clear all"
    assert_text "Device One"
    assert_no_text "matching your filters"
    assert_selector "[data-search-filter-target='filters']:not(.hidden)"
  end

  test "view all on rogues empty state resets the security filter" do
    sign_in
    visit "#{ip_addresses_path}?q%5Brogue_only%5D=true"
    assert_text "No rogue devices"
    click_on "Search & Filter"
    assert_checked_field "Rogue devices?"
    click_on "View all IPs"
    assert_no_text "No rogue devices"
    assert_unchecked_field "Rogue devices?"
  end

  test "view all on critical empty state resets the critical filter" do
    sign_in
    visit "#{devices_path}?q%5Bcritical_eq%5D=true"
    assert_text "No critical devices"
    click_on "Search & Filter"
    assert_equal "true", find_field("Critical device?").value
    click_on "View all devices"
    assert_no_text "No critical devices"
    assert_equal "", find_field("Critical device?").value
  end
end
