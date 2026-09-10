class AddUniqueIndexToAssignments < ActiveRecord::Migration[8.1]
  def change
    # Fail loudly on existing duplicates (no auto-dedupe by design).
    add_index :assignments, [ :card_id, :user_id ], unique: true
  end
end
