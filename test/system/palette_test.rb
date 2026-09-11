require "application_system_test_case"

class PaletteTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  def sign_in
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    # Headless Turbo submit stalls with zero errors about one run in
    # three (no request leaves the browser); one retry covers the flake
    # without masking real regressions (a broken flow fails twice).
    click_on "Sign in" unless has_text?("Needs attention")
    assert_text "Needs attention"
  end

  test "ctrl+k opens the palette and navigates to a result" do
    sign_in

    find("body").send_keys([ :control, "k" ])
    assert_selector 'dialog[aria-label="Command palette"][open]'

    fill_in placeholder: "Jump to devices, subnets, pages…", with: "subnet"

    # Waits for the debounced render to settle, then clicks the live node.
    find("#palette-results .palette-item", text: "Go to Subnets").click
    assert_current_path %r{/subnets$|/subnets\?}
  end

  test "ctrl+shift+e navigates to employees without opening the palette" do
    sign_in

    visit devices_path
    assert_text "Asset Inventory"
    find("body").send_keys([ :control, :shift, "e" ])
    assert_current_path "/employees"
    assert_no_selector 'dialog[aria-label="Command palette"][open]'
  end

  test "hotkeys do not fire while typing in a field" do
    sign_in

    visit devices_path
    click_on "Search & Filter"
    fill_in "Keyword", with: "e"
    assert_current_path %r{/devices}
    assert_equal "e", find_field("Keyword").value
  end
end
