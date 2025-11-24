class CreateBranches < ActiveRecord::Migration[8.1]
  def change
    create_table :branches do |t|
      t.string :name, null: false
      t.string :location
      t.string :contact_phone

      t.timestamps
    end
    # Integrity: No two branches can have the exact same name
    add_index :branches, :name, unique: true
  end
end
