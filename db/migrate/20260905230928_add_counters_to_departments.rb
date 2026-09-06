class AddCountersToDepartments < ActiveRecord::Migration[8.1]
  def change
    add_column :departments, :employees_count, :integer, default: 0, null: false
    add_column :departments, :devices_count, :integer, default: 0, null: false

    reversible do |direction|
      direction.up do
        Department.reset_column_information
        Department.find_each do |department|
          Department.reset_counters(department.id, :employees, :devices)
        end
      end
    end
  end
end
