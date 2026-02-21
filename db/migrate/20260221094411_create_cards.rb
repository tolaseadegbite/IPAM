class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :list, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.integer :position, null: false
      t.integer :priority, default: 0, null: false

      # Polymorphic link (Can be null if a task isn't about a specific device)
      t.references :referenceable, polymorphic: true, null: true

      t.timestamps
    end
    add_index :cards, [ :list_id, :position ]
  end
end
