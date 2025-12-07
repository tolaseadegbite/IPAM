class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :name, null: false             # Hostname
      t.string :serial_number, null: false
      t.string :asset_tag                     # Internal sticker ID
      t.integer :device_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.text :notes

      # Relationships
      t.references :department, null: false, foreign_key: true
      # Nullable: A device might be in storage and not assigned to a person yet
      t.references :employee, null: true, foreign_key: true

      t.timestamps
    end

    # Optimization: Critical for fast search
    add_index :devices, :serial_number, unique: true
    add_index :devices, :asset_tag, unique: true
    # Optimization: Speeds up "Find all Laptops"
    add_index :devices, :device_type
  end
end
