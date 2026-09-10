require "application_system_test_case"

class ProofPass2Test < ApplicationSystemTestCase
  def sign_in
    visit sign_in_path
    fill_in "Username", with: users(:lazaro_nixon).username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"
  end

  test "proof pass part 2 desktop" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    sign_in
    visit "/devices/#{Device.first.id}"
    assert_selector "main#main"
    save_screenshot("/tmp/opencode/proof2-device-show.png")
    visit "/boards/#{Board.first.id}"
    assert_selector "main#main"
    save_screenshot("/tmp/opencode/proof2-board-show.png")
  end

  test "proof pass part 2 mobile" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in
    visit "/devices/#{Device.first.id}"
    assert_selector "main#main"
    save_screenshot("/tmp/opencode/proof2-mobile-device-show.png")
  end
end
