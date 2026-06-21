class BulkCreateDevices < RubyLLM::Tool
  desc "Create multiple devices and assign IPs in one call. Use this when the user provides a list of 2+ devices instead of calling CreateDevice for each one individually."

  param :records_json, desc: <<~DESC.strip
    JSON array of device records. Each record has:
    - name (required): Device name
    - device_type (required): desktop, all_in_one, laptop, printer, server, tablet, biometrics_machine, or router
    - department_name (required): Department name (auto-created if missing)
    - ip_address (optional): IP to assign
    - employee_name (optional): Employee full name (auto-created if missing)
    - branch_name (optional): Branch override for this record (falls back to top-level branch_name)
    - mac_address (optional): MAC address (xx:xx:xx:xx:xx:xx)
    - location (optional): Physical location
    - notes (optional): Additional notes
  DESC
  param :branch_name, desc: "Default branch for auto-creating missing departments (default: Yale 1). Individual records can override this.", required: false

  def execute(records_json:, branch_name: nil)
    branch_name ||= "Yale 1"

    records = JSON.parse(records_json)
    return "records_json must be a JSON array." unless records.is_a?(Array)
    return "records_json is empty." if records.empty?

    lines = []
    successes = 0
    failures = 0

    records.each_with_index do |record, i|
      result = process_record(record, branch_name, i + 1)
      lines << result[:line]
      if result[:success]
        successes += 1
      else
        failures += 1
      end
    end

    summary = +"Processed #{records.size} record(s): #{successes} succeeded"
    summary << ", #{failures} failed" if failures > 0
    summary << ".\n\n"
    summary << lines.join("\n")
    summary
  end

  private

  def process_record(record, default_branch, index)
    name = record["name"] || record[:name]
    device_type = record["device_type"] || record[:device_type]
    department_name = record["department_name"] || record[:department_name]
    ip_address = record["ip_address"] || record[:ip_address]
    employee_name = record["employee_name"] || record[:employee_name]
    branch_name = record["branch_name"] || record[:branch_name] || default_branch
    mac_address = record["mac_address"] || record[:mac_address]
    location = record["location"] || record[:location]
    notes = record["notes"] || record[:notes]

    unless name && device_type && department_name
      return { line: "#{index}. FAILED: Missing required fields (name, device_type, department_name).", success: false }
    end

    created_resources = []

    unless Device.device_types.key?(device_type)
      valid_types = Device.device_types.keys.to_sentence
      return { line: "#{index}. #{name}: FAILED - Invalid device_type '#{device_type}'. Valid types: #{valid_types}.", success: false }
    end

    department = Department.joins(:branch).find_by(
      "departments.name ILIKE ? AND branches.name ILIKE ?",
      department_name, branch_name
    )

    unless department
      branch = Branch.find_by("name ILIKE ?", branch_name)
      unless branch
        similar = Branch.where("name ILIKE ?", "%#{branch_name}%").limit(5).pluck(:name)
        suggestions = similar.any? ? " Did you mean: #{similar.to_sentence}?" : ""
        return { line: "#{index}. #{name}: FAILED - Branch '#{branch_name}' not found.#{suggestions}", success: false }
      end

      department = Department.create!(name: department_name.strip, branch: branch)
      created_resources << "department '#{department_name}' in #{branch.name}"
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
      status: "active",
      department: department,
      employee: employee,
      mac_address: mac_address,
      location: location,
      notes: notes
    )

    unless device.save
      return { line: "#{index}. #{name}: FAILED - #{device.errors.full_messages.to_sentence}", success: false }
    end

    device_info = +"Created #{device_type} '#{name}'"
    device_info << " in #{department.name}"
    device_info << ", assigned to #{employee.full_name}" if employee
    if created_resources.any?
      device_info << " (auto-created: #{created_resources.to_sentence})"
    end

    if ip_address.present?
      ip = IpAddress.find_by(address: ip_address)

      unless ip
        device_info << ". Device created but IP #{ip_address} NOT FOUND in database."
        return { line: "#{index}. #{device_info}", success: true }
      end

      if ip.device_id.present?
        current_device = ip.device
        device_info << ". Device created but IP #{ip_address} already assigned to #{current_device.name}."
        return { line: "#{index}. #{device_info}", success: true }
      end

      if ip.blacklisted?
        device_info << ". Device created but IP #{ip_address} is blacklisted."
        return { line: "#{index}. #{device_info}", success: true }
      end

      ip.update!(device: device)
      device_info << ". Assigned IP #{ip_address}."
    end

    { line: "#{index}. #{device_info}", success: true }
  end
end
