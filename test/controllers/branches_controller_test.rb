require "test_helper"

class BranchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
    @branch = branches(:one)
  end

  test "should show branch hierarchy with collapsed departments" do
    get branch_url(@branch)
    assert_response :success

    @branch.departments.each do |department|
      # Each department renders as a collapsed disclosure with member rows present
      assert_select "details##{ActionView::RecordIdentifier.dom_id(department)}", count: 1
      assert_select "details##{ActionView::RecordIdentifier.dom_id(department)}", text: /#{Regexp.escape(department.name)}/
    end
  end

  test "should not show matching summary for blank filters" do
    # Cleared forms submit empty q values; the summary must only reflect
    # truly active filters.
    get branches_url(q: { name_cont: "" })
    assert_response :success
    assert_select "p", text: /matching your filters/, count: 0
  end

  test "should show department members inline" do
    department = departments(:one)
    get branch_url(department.branch)
    assert_response :success

    department.employees.each do |employee|
      assert_select "details", text: /#{Regexp.escape(employee.full_name)}/
    end
    department.devices.each do |device|
      assert_select "details", text: /#{Regexp.escape(device.name)}/
    end
  end

  test "should show branch subnets" do
    subnet = subnets(:one)
    subnet.update!(branch: @branch)

    get branch_url(@branch)
    assert_response :success
    assert_select "a[href=?]", subnet_path(subnet), count: 1
  end
end
