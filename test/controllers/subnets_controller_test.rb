require "test_helper"

class SubnetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should show subnet" do
    get subnet_url(subnets(:one))
    assert_response :success
  end

  test "should create subnet with branch" do
    assert_difference "Subnet.count" do
      post subnets_url, params: { subnet: { name: "Lab", network_address: "10.9.9.0/24",
                                            gateway: "10.9.9.1", branch_id: branches(:one).id } }
    end

    assert_equal branches(:one), Subnet.last.branch
    assert_redirected_to subnets_url
  end

  test "should assign and unassign branch on update" do
    subnet = subnets(:one)

    patch subnet_url(subnet), params: { subnet: { branch_id: branches(:one).id } }
    assert_redirected_to subnets_url
    assert_equal branches(:one), subnet.reload.branch

    patch subnet_url(subnet), params: { subnet: { branch_id: "" } }
    assert_redirected_to subnets_url
    assert_nil subnet.reload.branch
  end

  test "should filter subnets by branch" do
    subnets(:one).update!(branch: branches(:one))

    get subnets_url(q: { branch_id_eq: branches(:one).id })
    assert_response :success
    assert_select "turbo-frame#subnets_table", count: 1
  end
end
