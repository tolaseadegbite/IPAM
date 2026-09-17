require "test_helper"

class IpAddressesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show ip address" do
    get ip_address_url(ip_addresses(:one))
    assert_response :success
  end

  test "select_options answers frame requests with turbo stream" do
    get select_options_ip_addresses_url(subnet_id: subnets(:one).id),
        headers: { "Turbo-Frame" => "ip_options_1" }
    assert_response :success
    assert_match(/turbo-stream action="update" target="ip_options_1"/, response.body)
  end

  test "should render neutral empty state with no rogues" do
    # Fixture IPs are all assigned, so the rogue scope is empty and the
    # shared neutral empty state renders (regression: LocalJumpError from
    # a capture block bound to render instead of capture).
    get ip_addresses_url(q: { rogue_only: "true" })
    assert_response :success
    assert_select "p", text: "No rogue devices"
  end

  test "should not show active filters for blank filters" do
    # Cleared forms submit empty q values; pills must only reflect
    # truly active filters.
    get ip_addresses_url(q: { address_string_cont: "" })
    assert_response :success
    assert_select "span", text: "Active filters:", count: 0
  end

  test "should show active filters for real filters" do
    get ip_addresses_url(q: { address_string_cont: "10.0.1" })
    assert_response :success
    assert_select "span", text: "Active filters:", count: 1
  end
end
