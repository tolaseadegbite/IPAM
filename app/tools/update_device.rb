class UpdateDevice < RubyLLM::Tool
  desc "Update an existing device's fields. Only provided fields will be changed. Pass an empty string to clear a field."

  param :name, desc: "The name of the device to update"
  param :new_name, desc: "New name for the device", required: false
  param :device_type, desc: "Type: desktop, all_in_one, laptop, printer, server, tablet, biometrics_machine, or router", required: false
  param :status, desc: "Status: active, in_storage, in_repair, retired, or lost", required: false
  param :mac_address, desc: "MAC address (format: xx:xx:xx:xx:xx:xx). Pass empty string to clear.", required: false
  param :department_name, desc: "New department name. Provide branch_name if the department is new or ambiguous.", required: false
  param :branch_name, desc: "Branch name for finding or auto-creating the department", required: false
  param :employee_name, desc: "Full name of the employee to assign. Pass empty string to unassign.", required: false
  param :location, desc: "Physical location of the device", required: false
  param :notes, desc: "Additional notes about the device", required: false

  def execute(name:, new_name: nil, device_type: nil, status: nil, mac_address: nil, department_name: nil, branch_name: nil, employee_name: nil, location: nil, notes: nil)
    device = Device.find_by(name: name)

    unless device
      return "Device '#{name}' not found. Use LookupDevice to search."
    end

    changes = []

    if new_name.present?
      device.name = new_name
      changes << "name to '#{new_name}'"
    end

    if device_type.present?
      unless Device.device_types.key?(device_type)
        valid_types = Device.device_types.keys.to_sentence
        return "Invalid device_type '#{device_type}'. Valid types: #{valid_types}."
      end
      device.device_type = device_type
      changes << "type to #{device_type}"
    end

    if status.present?
      unless Device.statuses.key?(status)
        valid_statuses = Device.statuses.keys.to_sentence
        return "Invalid status '#{status}'. Valid statuses: #{valid_statuses}."
      end
      device.status = status
      changes << "status to #{status}"
    end

    if mac_address.nil? == false
      device.mac_address = mac_address.presence
      changes << (mac_address.present? ? "MAC to #{mac_address}" : "MAC cleared")
    end

    if notes.nil? == false
      device.notes = notes.presence
      changes << (notes.present? ? "notes updated" : "notes cleared")
    end

    if location.nil? == false
      device.location = location.presence
      changes << (location.present? ? "location to #{location}" : "location cleared")
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

      device.department = department
      changes << "department to #{department.name}"
    end

    if employee_name.nil? == false
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
            department: device.department,
            status: :active
          )
          changes << "new employee '#{employee.full_name}' created and assigned"
        else
          changes << "assigned to #{employee.full_name}"
        end

        device.employee = employee
      else
        if device.employee
          changes << "unassigned from #{device.employee.full_name}"
        end
        device.employee = nil
      end
    end

    if changes.empty?
      return "No changes provided. Specify at least one field to update."
    end

    if device.save
      "Updated '#{name}': #{changes.to_sentence}."
    else
      "Failed to update device: #{device.errors.full_messages.to_sentence}."
    end
  end
end
