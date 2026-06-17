class AddIpAddressesCountToSubnets < ActiveRecord::Migration[8.1]
  def change
    add_column :subnets, :ip_addresses_count, :integer, default: 0, null: false

    up_only do
      Subnet.find_each do |subnet|
        Subnet.reset_counters(subnet.id, :ip_addresses)
      end
    end
  end
end
