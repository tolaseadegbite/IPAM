class RemoveSudoAtFromSessions < ActiveRecord::Migration[8.1]
  def change
    remove_column :sessions, :sudo_at, :datetime
  end
end
