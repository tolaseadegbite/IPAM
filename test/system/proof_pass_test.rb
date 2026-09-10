require "application_system_test_case"

class ProofPassTest < ApplicationSystemTestCase
  def sign_in
    visit sign_in_path
    fill_in "Username", with: users(:lazaro_nixon).username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"
  end

  test "proof pass desktop" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    sign_in
    {
      "devices" => devices_path,
      "employees" => employees_path,
      "branches" => branches_path,
      "departments" => departments_path,
      "subnets" => subnets_path,
      "ip_addresses" => ip_addresses_path,
      "users" => admin_users_path
    }.each do |name, path|
      visit path
      assert_selector "main#main"
      save_screenshot("/tmp/opencode/proof-desktop-#{name}.png")
    end
  end

  test "proof pass mobile" do
    sign_in
    page.driver.browser.manage.window.resize_to(390, 844)
    {
      "devices" => devices_path,
      "employees" => employees_path,
      "ip_addresses" => ip_addresses_path
    }.each do |name, path|
      visit path
      assert_selector "main#main"
      save_screenshot("/tmp/opencode/proof-mobile-#{name}.png")
    end
  end
end
