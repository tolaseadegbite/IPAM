require "application_system_test_case"

class PaletteTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "ctrl+k opens the palette and navigates to a result" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"

    find("body").send_keys([ :control, "k" ])
    assert_selector 'dialog[aria-label="Command palette"][open]'

    fill_in placeholder: "Jump to devices, subnets, pages…", with: "subnet"

    # Waits for the debounced render to settle, then clicks the live node.
    find("#palette-results .palette-item", text: "Go to Subnets").click
    assert_current_path %r{/subnets$|/subnets\?}
  end
end
