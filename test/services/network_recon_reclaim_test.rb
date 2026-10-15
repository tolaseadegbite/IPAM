require "test_helper"

class NetworkReconReclaimTest < ActiveSupport::TestCase
  setup do
    @subnet = subnets(:one)
    @device = devices(:one)
    @service = NetworkReconService.new
    # Test env uses null_store: swap in memory so the freshness gate
    # behaves like production. Restored after each test.
    @real_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    # Gate open: a sweep ran just now.
    Rails.cache.write("subnet_last_swept_at_10.0.1.0/24", Time.current)
  end

  teardown do
    Rails.cache = @real_cache
  end

  def stale_link(address:, dark_for:, status: :active)
    ip = IpAddress.create!(
      subnet: @subnet, address: address, status: status,
      reachability_status: :down, device: @device
    )
    ip.update_column(:last_seen_at, dark_for.ago)
    ip
  end

  test "keeps links dark within the grace window" do
    ip = stale_link(address: "10.0.1.60", dark_for: NetworkReconService::RECLAIM_AFTER - 1.day)

    assert_no_difference "NetworkEvent.count" do
      assert_equal 0, @service.reclaim_stale_links!("10.0.1.0/24")
    end

    assert_equal @device.id, ip.reload.device_id
  end

  test "releases links dark beyond the grace window" do
    ip = stale_link(address: "10.0.1.61", dark_for: NetworkReconService::RECLAIM_AFTER + 1.day)

    assert_difference "NetworkEvent.count", 1 do
      assert_equal 1, @service.reclaim_stale_links!("10.0.1.0/24")
    end

    ip.reload
    assert_nil ip.device_id
    assert ip.available?
    assert IpAddress.exists?(ip.id), "reclaim unlinks, never deletes"

    event = NetworkEvent.order(:id).last
    assert event.kind_info?
    assert_equal @device.id, event.device_id
    assert_match(/10\.0\.1\.61/, event.message)
  end

  test "never touches reserved rows" do
    ip = stale_link(address: "10.0.1.62", dark_for: 30.days, status: :reserved)

    assert_no_difference "NetworkEvent.count" do
      assert_equal 0, @service.reclaim_stale_links!("10.0.1.0/24")
    end

    assert_equal @device.id, ip.reload.device_id
  end

  test "leaves live legs of multi-homed devices alone" do
    live = IpAddress.create!(
      subnet: @subnet, address: "10.0.1.63", status: :active,
      reachability_status: :up, device: @device,
      last_seen_at: Time.current
    )
    stale_link(address: "10.0.1.64", dark_for: NetworkReconService::RECLAIM_AFTER + 1.day)

    assert_equal 1, @service.reclaim_stale_links!("10.0.1.0/24")

    assert_equal @device.id, live.reload.device_id
    assert live.reachability_status_up?
  end

  test "ignores other subnets" do
    other_subnet = subnets(:two)
    ip = IpAddress.create!(
      subnet: other_subnet, address: "10.0.2.60", status: :active,
      reachability_status: :down, device: devices(:two)
    )
    ip.update_column(:last_seen_at, 20.days.ago)

    assert_equal 0, @service.reclaim_stale_links!("10.0.1.0/24")
    assert_equal devices(:two).id, ip.reload.device_id
  end

  test "skips releases with no recent sweep" do
    Rails.cache.delete("subnet_last_swept_at_10.0.1.0/24")
    ip = stale_link(address: "10.0.1.65", dark_for: 30.days)

    assert_no_difference "NetworkEvent.count" do
      assert_equal 0, @service.reclaim_stale_links!("10.0.1.0/24")
    end

    assert_equal @device.id, ip.reload.device_id
  end

  test "back-to-back sweeps skip then release" do
    Rails.cache.delete("subnet_last_swept_at_10.0.1.0/24")
    ip = stale_link(address: "10.0.1.66", dark_for: 30.days)

    assert_equal 0, @service.reclaim_stale_links!("10.0.1.0/24")
    assert_equal @device.id, ip.reload.device_id

    assert_equal 1, @service.reclaim_stale_links!("10.0.1.0/24")
    assert_nil ip.reload.device_id
  end
end
