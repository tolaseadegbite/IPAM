class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :status, default: 0, null: false # 0: Active, 1: On Leave...
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end
    add_index :employees, :status
  end
end
