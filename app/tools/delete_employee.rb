class DeleteEmployee < RubyLLM::Tool
  desc "Delete an employee by name. Will only proceed if the employee has no devices assigned."

  param :name, desc: "The full name of the employee to delete"

  def execute(name:)
    parts = name.strip.split(/\s+/, 2)
    employee = Employee.where("first_name ILIKE ? AND last_name ILIKE ?", parts[0], parts[1] || "")
                        .or(Employee.where("first_name ILIKE ?", parts[0]))
                        .first

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
