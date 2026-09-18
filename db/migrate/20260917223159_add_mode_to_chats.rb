class AddModeToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :mode, :string, null: false, default: "plan"
  end
end
