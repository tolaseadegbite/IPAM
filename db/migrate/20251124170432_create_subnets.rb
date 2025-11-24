class CreateSubnets < ActiveRecord::Migration[8.1]
  def change
    create_table :subnets do |t|
      t.string :name, null: false              # e.g., "Corporate Data"
      t.cidr :network_address, null: false     # PostgreSQL CIDR type (192.168.13.0/24)
      t.inet :gateway                          # PostgreSQL INET type
      t.integer :vlan_id

      t.timestamps
    end
    # Integrity: Unique network ranges
    add_index :subnets, :network_address, unique: true
  end
end
