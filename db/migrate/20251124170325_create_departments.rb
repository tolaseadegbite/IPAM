class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.string :name, null: false
      t.references :branch, null: false, foreign_key: true

      t.timestamps
    end
    
    # Optimization: Composite Index
    # This prevents duplicate dept names within the SAME branch,
    # but allows "Safety Office" to exist in both "Yale 1" and "Yale 5".
    # It also speeds up queries like: Department.where(branch_id: 1, name: "Safety")
    add_index :departments, [:name, :branch_id], unique: true
  end
end
