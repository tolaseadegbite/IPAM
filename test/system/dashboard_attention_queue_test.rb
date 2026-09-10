require "application_system_test_case"

class DashboardAttentionQueueTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "reclaiming a ghost asset from the attention queue" do
    device = devices(:one)
    ghost = ip_addresses(:one)
    ghost.update!(device: device, status: :active,
                  reachability_status: :down, last_seen_at: 45.days.ago)

    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"

    visit root_path
    assert_selector "#attention-ip-#{ghost.id}", text: "Reclaim"

    within "#attention-ip-#{ghost.id}" do
      click_on "Reclaim"
    end

    assert_no_selector "#attention-ip-#{ghost.id}"
    assert_equal "available", ghost.reload.status
    assert_nil ghost.device_id
  end
end
