require "application_system_test_case"

class TrendRangeTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "switching chart range swaps datasets without reload" do
    visit sign_in_path
    fill_in "Username", with: @user.username
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Sign in"
    assert_text "Needs attention"

    visit root_path
    assert_text "Network events", wait: 10

    counts = evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector('[data-controller="trend-range"]');
        const sets = JSON.parse(el.dataset.trendRangeDatasetsValue);
        return Object.fromEntries(Object.entries(sets).map(([k, v]) => [k, v.labels.length]));
      })()
    JS
    assert_equal({ "1h" => 12, "24h" => 24, "7d" => 7, "14d" => 14 }, counts)
    assert_selector 'button[aria-pressed="true"]', text: "14D"

    click_on "7D"

    assert_selector 'button[aria-pressed="true"]', text: "7D"
    labels_7d = evaluate_script(<<~JS)
      JSON.parse(document.querySelector('[data-controller="trend-range"] canvas').dataset.chartDataValue).labels
    JS
    assert_equal 7, labels_7d.size

    click_on "1H"

    assert_selector 'button[aria-pressed="true"]', text: "1H"
    labels_1h = evaluate_script(<<~JS)
      JSON.parse(document.querySelector('[data-controller="trend-range"] canvas').dataset.chartDataValue).labels
    JS
    assert_equal 12, labels_1h.size
    assert labels_1h.all? { |l| l.match?(/\A\d{2}:\d{2}\z/) }, "expected time labels, got #{labels_1h.inspect}"
  end
end
