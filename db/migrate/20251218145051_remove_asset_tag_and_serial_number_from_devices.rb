class RemoveAssetTagAndSerialNumberFromDevices < ActiveRecord::Migration[8.1]
  def change
    remove_column :devices, :asset_tag, :string
    remove_column :devices, :serial_number, :string
  end
end
