require "application_system_test_case"

class DocsMobileTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  teardown do
    page.current_window.resize_to(1400, 1400)
  end

  test "docs pages have no horizontal overflow on phones" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    page.current_window.resize_to(375, 812)

    DocsController::PAGES.each_key do |slug|
      visit doc_page_path(slug)
      report = evaluate_script(<<~JS)
        (() => {
          const bad = [];
          document.querySelectorAll("body *").forEach((el) => {
            const cls = el.className && el.className.split ? el.className : "";
            const r = el.getBoundingClientRect();
            if (r.right > window.innerWidth + 1 || r.left < -1) {
              bad.push(`${el.tagName}.${cls.split(" ").slice(0, 3).join(".")}@${Math.round(r.right)}`);
            }
          });
          const uniq = [...new Set(bad)].slice(0, 10);
          return { overflow: document.scrollingElement.scrollWidth - window.innerWidth, offenders: uniq };
        })()
      JS
      assert report["overflow"] <= 0, "horizontal overflow on #{slug}: #{report["offenders"].inspect}"
    end
  end

  test "mobile guide disclosure navigates" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention", wait: 10

    page.current_window.resize_to(375, 812)
    visit doc_page_path("welcome")

    find("details summary", text: "Guides").click
    within("details") { click_on "Dashboard" }

    assert_selector "article h1", text: "Dashboard"
  end
end
