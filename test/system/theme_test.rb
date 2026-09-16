require "application_system_test_case"

class ThemeTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "switching to an Omarchy theme re-skins the app" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"

    visit root_path
    assert_text "Needs attention", wait: 10
    assert_equal "#0ea5e9", evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--chart-info').trim()")
    click_on "Theme"
    click_on "Osaka Jade"

    assert_selector 'html[data-theme="osaka-jade"].dark'
    assert_equal "rgb(9, 15, 13)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    refresh
    assert_selector 'html[data-theme="osaka-jade"].dark'

    click_on "Theme"
    click_on "Solitude"

    assert_selector 'html[data-theme="solitude"].dark'
    assert_equal "rgb(8, 10, 11)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Giants"

    assert_selector 'html[data-theme="giants"].dark'
    assert_equal "rgb(20, 18, 16)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Retro 82"

    assert_selector 'html[data-theme="retro-82"].dark'
    assert_equal "rgb(2, 12, 23)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Miasma"

    assert_selector 'html[data-theme="miasma"].dark'
    assert_equal "rgb(18, 18, 18)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Tokyo Night"

    assert_selector 'html[data-theme="tokyo-night"].dark'
    assert_equal "rgb(14, 14, 20)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Matte Black"

    assert_selector 'html[data-theme="matte-black"].dark'
    assert_equal "rgb(9, 9, 9)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Gruvbox"

    assert_selector 'html[data-theme="gruvbox"].dark'
    assert_equal "rgb(22, 22, 22)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Everforest"

    assert_selector 'html[data-theme="everforest"].dark'
    assert_equal "rgb(24, 29, 32)", evaluate_script("getComputedStyle(document.body).backgroundColor")

    click_on "Theme"
    click_on "Dark"
    assert_selector 'html[data-theme="everforest"].dark'

    click_on "Theme"
    click_on "Light"
    assert_no_selector "html[data-theme]"
  end

  test "theme popover anchors next to its trigger" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"

    visit root_path
    assert_text "Needs attention", wait: 10
    click_on "Theme"

    pos = nil
    25.times do
      pos = evaluate_script(<<~JS)
        (() => {
          const trigger = [...document.querySelectorAll("button")].find((b) => b.textContent.trim() === "Theme");
          const content = [...document.querySelectorAll(".popover")].find((p) => p.textContent.includes("Osaka Jade"));
          const t = trigger.getBoundingClientRect(), c = content.getBoundingClientRect();
          return { open: content.matches(":popover-open"), tRight: t.right, tTop: t.top, cLeft: c.left, cTop: c.top, cBottom: c.bottom, vh: innerHeight };
        })()
      JS
      break if pos["open"] && pos["cBottom"] <= pos["vh"]
      sleep 0.2
    end

    assert pos["open"], "expected Theme popover to be open"
    assert pos["cLeft"] >= pos["tRight"] - 8, "expected popover right of trigger, got #{pos.inspect}"
    # Tall menus shift up to stay visible; require vertical overlap with the
    # trigger instead of exact top alignment.
    assert pos["cTop"] <= pos["tTop"] + 8 && pos["cBottom"] >= pos["tTop"], "expected popover overlapping trigger height, got #{pos.inspect}"
    assert pos["cTop"] >= 0 && pos["cBottom"] <= pos["vh"], "expected popover inside viewport, got #{pos.inspect}"
  end
end
