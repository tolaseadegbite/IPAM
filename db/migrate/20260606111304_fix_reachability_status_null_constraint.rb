class FixReachabilityStatusNullConstraint < ActiveRecord::Migration[8.1]
  def up
    IpAddress.where(reachability_status: nil).update_all(reachability_status: 0)
    change_column_null :ip_addresses, :reachability_status, false
    change_column_default :ip_addresses, :reachability_status, from: nil, to: 0
  end

  def down
    change_column_default :ip_addresses, :reachability_status, from: 0, to: nil
    change_column_null :ip_addresses, :reachability_status, true
  end
end
