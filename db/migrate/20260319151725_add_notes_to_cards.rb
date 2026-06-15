class AddNotesToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :notes, :text
  end
end
