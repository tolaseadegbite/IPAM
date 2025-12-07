class AddCriticalToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :critical, :boolean, default: false
  end
end
