class AddLocationToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :location, :string
  end
end
