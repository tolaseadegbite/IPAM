class LookupDepartment < RubyLLM::Tool
  desc "Search for departments by name or branch name"

  param :query, desc: "Department name or branch name to search for"

  def execute(query:)
    Department.left_joins(:branch)
              .includes(:branch)
              .where("departments.name ILIKE :q OR branches.name ILIKE :q", q: "%#{query}%")
              .limit(20)
              .map do |d|
      {
        id: d.id,
        name: d.name,
        branch: d.branch&.name,
        employee_count: d.employees.count,
        device_count: d.devices.count
      }
    end
  end
end
