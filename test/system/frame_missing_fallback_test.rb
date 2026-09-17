require "application_system_test_case"

class FrameMissingFallbackTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "frameless frame response falls back to full visit" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    visit devices_path
    assert_selector "#devices_table"

    evaluate_script("document.getElementById('devices_table').src = '/up'")

    assert_current_path rails_health_check_path
    assert_no_selector ".turbo-frame-error"
  end
end
