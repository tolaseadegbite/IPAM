class CreateLists < ActiveRecord::Migration[8.1]
  def change
    create_table :lists do |t|
      t.references :board, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false # acts_as_list needs this

      t.timestamps
    end
    # Index for faster sorting
    add_index :lists, [ :board_id, :position ]
  end
end
