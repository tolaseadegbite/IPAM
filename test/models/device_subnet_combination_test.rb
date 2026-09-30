require "test_helper"

class DeviceSubnetCombinationTest < ActiveSupport::TestCase
  setup do
    @corp = Subnet.create!(name: "Corporate", network_address: "192.168.13.0/24", gateway: "192.168.13.1")
    @alt = Subnet.create!(name: "Alt Corp", network_address: "192.168.30.0/24", gateway: "192.168.30.1")
    @y15 = Subnet.create!(name: "Yale 15", network_address: "172.15.242.0/24", gateway: "172.15.242.1")
    @y16 = Subnet.create!(name: "Yale 16", network_address: "172.16.242.0/24", gateway: "172.16.242.1")
  end

  def new_device
    Device.new(
      name: "Combo Box #{SecureRandom.hex(3)}", device_type: :desktop,
      status: :active, department: departments(:one)
    )
  end

  def ip_of(subnet, host)
    base = subnet.network_address.to_s.split("/").first.split(".")[0..2].join(".")
    IpAddress.find_by!(address: "#{base}.#{host}")
  end

  test "valid multi-segment set saves" do
    device = new_device
    device.ip_address_ids = [ ip_of(@y16, 10).id, ip_of(@corp, 10).id ]

    assert device.valid?, device.errors.full_messages.to_sentence
  end

  test "duplicate series is invalid" do
    device = new_device
    device.ip_address_ids = [ ip_of(@corp, 10).id, ip_of(@corp, 11).id ]

    assert_not device.valid?
    assert_match(/one series per device/i, device.errors[:ip_addresses].to_sentence)
  end

  test "exclusive pairs are invalid" do
    forbidden = [
      [ ip_of(@corp, 10).id, ip_of(@alt, 10).id ],
      [ ip_of(@y15, 10).id, ip_of(@y16, 10).id ]
    ]

    forbidden.each do |ids|
      device = new_device
      device.ip_address_ids = ids

      assert_not device.valid?
      assert_match(/either side, not both/i, device.errors[:ip_addresses].to_sentence)
    end
  end
end
