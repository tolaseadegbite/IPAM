class AddDashboardIndexes < ActiveRecord::Migration[8.1]
  # Hot dashboard filters/groupings. Plain (non-concurrent) indexes:
  # these tables are small and short locks are harmless.
  def change
    add_index :ip_addresses, :status
    add_index :ip_addresses, :reachability_status
    add_index :ip_addresses, :last_seen_at
    add_index :devices, :critical
    add_index :network_events, [ :created_at, :kind ]
  end
end
