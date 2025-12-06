class AddMonitoringFields < ActiveRecord::Migration[8.1]
  def change
    # 1. The Fingerprint for the Device
    add_column :devices, :mac_address, :string
    add_index :devices, :mac_address, unique: true

    # 2. Monitoring status for the IP
    add_column :ip_addresses, :reachability_status, :integer, default: 0
    add_column :ip_addresses, :last_seen_at, :datetime
  end
end
