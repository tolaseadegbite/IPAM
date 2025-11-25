class AddNotesToIpAddresses < ActiveRecord::Migration[8.1]
  def change
    add_column :ip_addresses, :notes, :text
  end
end
