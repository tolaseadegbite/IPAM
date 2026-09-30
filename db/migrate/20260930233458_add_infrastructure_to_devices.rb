class AddInfrastructureToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :infrastructure, :boolean, default: false, null: false
  end
end
