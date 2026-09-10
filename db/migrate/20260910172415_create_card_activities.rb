class CreateCardActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :card_activities do |t|
      t.references :card, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true # nil = System/scanner
      t.integer :action, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :card_activities, [ :card_id, :created_at ]
    add_index :card_activities, :action
  end
end
