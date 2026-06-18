class CreateDevice < RubyLLM::Tool
  desc "Create a new device. If the department or employee doesn't exist, provide enough info and they will be auto-created."

  param :name, desc: "Device name (must be unique)"
  param :device_type, desc: "Type of device: desktop, all_in_one, laptop, printer, server, tablet, biometrics_machine, or router"
  param :department_name, desc: "Name of the department this device belongs to. If the department doesn't exist, provide branch_name to auto-create it."
  param :branch_name, desc: "Branch name for auto-creating a new department (required if department doesn't exist yet)", required: false
  param :status, desc: "Device status: active, in_storage, in_repair, retired, or lost (default: active)", required: false
  param :mac_address, desc: "MAC address (format: xx:xx:xx:xx:xx:xx)", required: false
  param :employee_name, desc: "Full name of the employee assigned to this device. If the employee doesn't exist, they will be auto-created.", required: false
  param :location, desc: "Physical location of the device", required: false
  param :notes, desc: "Additional notes about the device", required: false

  def execute(name:, device_type:, department_name:, branch_name: nil, status: nil, mac_address: nil, employee_name: nil, location: nil, notes: nil)
    unless Device.device_types.key?(device_type)
      valid_types = Device.device_types.keys.to_sentence
      return "Invalid device_type '#{device_type}'. Valid types: #{valid_types}."
    end

    status_value = status.presence || "active"

    unless Device.statuses.key?(status_value)
      valid_statuses = Device.statuses.keys.to_sentence
      return "Invalid status '#{status_value}'. Valid statuses: #{valid_statuses}."
    end

    created_resources = []

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
        created_resources << "department '#{department_name}' in #{branch.name} branch"
      else
        similar = Department.where("name ILIKE ?", "%#{department_name}%").limit(5).pluck(:name)
        suggestions = similar.any? ? " Did you mean: #{similar.to_sentence}?" : ""
        return "Department '#{department_name}' not found.#{suggestions} Provide a branch_name to auto-create it."
      end
    end

    employee = nil
    if employee_name.present?
      parts = employee_name.strip.split(/\s+/, 2)
      employee = if parts[1].present?
          Employee.find_by("first_name ILIKE ? AND last_name ILIKE ?", parts[0], parts[1])
      else
          Employee.find_by("first_name ILIKE ?", parts[0])
      end

      unless employee
        employee = Employee.create!(
          first_name: parts[0].capitalize,
          last_name: parts[1]&.capitalize.presence || "",
          department: department,
          status: :active
        )
        created_resources << "employee '#{employee.full_name}'"
      end
    end

    device = Device.new(
      name: name,
      device_type: device_type,
      status: status_value,
      department: department,
      employee: employee,
      mac_address: mac_address,
      location: location,
      notes: notes
    )

    if device.save
      result = +"Created #{device_type} '#{name}'"
      result << " (status: #{status_value})"
      result << " in #{department.name}"
      result << ", assigned to #{employee.full_name}" if employee
      if created_resources.any?
        result << ". Also auto-created: #{created_resources.to_sentence}."
      else
        result << "."
      end
      result
    else
      "Failed to create device: #{device.errors.full_messages.to_sentence}."
    end
  end
end
