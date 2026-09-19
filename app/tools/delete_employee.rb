class DeleteEmployee < RubyLLM::Tool
  description "Delete an employee by name. Will only proceed if the employee has no devices assigned."

  parameter :name, description: "The full name of the employee to delete"

  def execute(name:)
    parts = name.strip.split(/\s+/, 2)

    # Destructive action: never guess. Require a full name, and refuse
    # when it still matches more than one employee.
    unless parts[1].present?
      return "Please provide the employee's full name (first and last). Use LookupEmployee to search."
    end

    matches = Employee.where("first_name ILIKE ? AND last_name ILIKE ?", parts[0], parts[1])

    if matches.count > 1
      list = matches.limit(10).map(&:full_name).to_sentence
      return "Multiple employees match '#{name}': #{list}. Please specify which one to delete."
    end

    employee = matches.first

    unless employee
      return "Employee '#{name}' not found. Use LookupEmployee to search."
    end

    device_count = Device.where(employee_id: employee.id).count
    if device_count > 0
      device_names = Device.where(employee_id: employee.id).limit(10).pluck(:name)
      list = device_names.map { |n| "'#{n}'" }.to_sentence
      return "Cannot delete #{employee.full_name} — they have #{device_count} device(s) assigned: #{list}. Reassign or delete them first."
    end

    employee.destroy!

    "Deleted employee #{employee.full_name}."
  end
end
