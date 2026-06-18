class UpdateEmployee < RubyLLM::Tool
  desc "Update an existing employee's fields. Only provided fields will be changed."

  param :name, desc: "The full name of the employee to update"
  param :first_name, desc: "New first name", required: false
  param :last_name, desc: "New last name", required: false
  param :department_name, desc: "New department name. Provide branch_name if the department is new or ambiguous.", required: false
  param :branch_name, desc: "Branch name for finding or auto-creating the department", required: false
  param :status, desc: "Status: active, on_leave, or terminated", required: false

  def execute(name:, first_name: nil, last_name: nil, department_name: nil, branch_name: nil, status: nil)
    parts = name.strip.split(/\s+/, 2)
    employee = Employee.where("first_name ILIKE ? AND last_name ILIKE ?", parts[0], parts[1] || "")
                        .or(Employee.where("first_name ILIKE ?", parts[0]))
                        .first

    unless employee
      return "Employee '#{name}' not found. Use LookupEmployee to search."
    end

    changes = []

    if first_name.present?
      employee.first_name = first_name.strip.capitalize
      changes << "first name to #{employee.first_name}"
    end

    if last_name.nil? == false
      employee.last_name = last_name.presence&.capitalize || ""
      changes << (last_name.present? ? "last name to #{employee.last_name}" : "last name cleared")
    end

    if status.present?
      unless Employee.statuses.key?(status)
        valid_statuses = Employee.statuses.keys.to_sentence
        return "Invalid status '#{status}'. Valid statuses: #{valid_statuses}."
      end
      employee.status = status
      changes << "status to #{status}"
    end

    if department_name.present?
      department = if branch_name.present?
        Department.joins(:branch).find_by(
          "departments.name ILIKE ? AND branches.name ILIKE ?",
          department_name, branch_name
        )
      else
        Department.find_by("name ILIKE ?", department_name)
      end

      unless department
        if branch_name.present?
          branch = Branch.find_by("name ILIKE ?", branch_name)
          unless branch
            similar = Branch.where("name ILIKE ?", "%#{branch_name}%").limit(5).pluck(:name)
            suggestions = similar.any? ? " Did you mean: #{similar.to_sentence}?" : ""
            return "Branch '#{branch_name}' not found.#{suggestions}"
          end
          department = Department.create!(name: department_name.strip, branch: branch)
        else
          similar = Department.where("name ILIKE ?", "%#{department_name}%").limit(5).pluck(:name)
          suggestions = similar.any? ? " Did you mean: #{similar.to_sentence}?" : ""
          return "Department '#{department_name}' not found.#{suggestions} Provide a branch_name to find or auto-create it."
        end
      end

      employee.department = department
      changes << "department to #{department.name}"
    end

    if changes.empty?
      return "No changes provided. Specify at least one field to update."
    end

    if employee.save
      "Updated #{employee.full_name}: #{changes.to_sentence}."
    else
      "Failed to update employee: #{employee.errors.full_messages.to_sentence}."
    end
  end
end
