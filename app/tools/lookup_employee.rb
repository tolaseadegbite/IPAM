class LookupEmployee < RubyLLM::Tool
  desc "Search for employees by name, department, or status"

  param :query, desc: "Employee name, department name, or status to search for"

  def execute(query:)
    Employee.left_joins(:department)
            .includes(:department)
            .where("first_name ILIKE :q OR last_name ILIKE :q OR departments.name ILIKE :q", q: "%#{query}%")
            .limit(20)
            .map do |e|
      {
        id: e.id,
        name: e.full_name,
        department: e.department&.name,
        status: e.status,
        devices: e.devices.map { |d| { name: d.name, type: d.device_type } }
      }
    end
  end
end
