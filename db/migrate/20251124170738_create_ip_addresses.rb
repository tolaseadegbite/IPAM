class CreateIpAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :ip_addresses do |t|
      t.inet :address, null: false            # PostgreSQL INET type
      t.integer :status, default: 0, null: false 
      
      # Relationships
      t.references :subnet, null: false, foreign_key: true
      # Nullable: If null, the IP is "Available". If present, it is "Used".
      t.references :device, null: true, foreign_key: true 

      t.timestamps
    end

    # Integrity: The exact same IP cannot exist twice
    add_index :ip_addresses, :address, unique: true
  end
end
