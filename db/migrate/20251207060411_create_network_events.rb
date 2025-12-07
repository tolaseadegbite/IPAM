class CreateNetworkEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :network_events do |t|
      t.string :message, null: false
      t.inet :ip_address
      t.references :device, foreign_key: true
      t.integer :kind, default: 0

      t.datetime :created_at, null: false
      # No updated_at needed, logs are immutable
    end
  end
end
