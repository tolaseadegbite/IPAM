class AddBranchToSubnets < ActiveRecord::Migration[8.1]
  def change
    add_reference :subnets, :branch, null: true, foreign_key: true
  end
end
