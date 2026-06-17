class GetDeviceBreakdown < RubyLLM::Tool
  desc "Get device counts broken down by type (laptop, desktop, server, etc.), optionally filtered by department or branch"

  param :department, desc: "Department name to filter by (optional)"
  param :branch, desc: "Branch name to filter by (optional)"

  IGNORE_FILTERS = %w[all any every].freeze

  def execute(department: nil, branch: nil)
    department = nil if department.blank? || department.downcase.in?(IGNORE_FILTERS)
    branch = nil if branch.blank? || branch.downcase.in?(IGNORE_FILTERS)

    devices = Device.left_joins(:department)

    if department.present?
      devices = devices.where(departments: { name: department })
    end

    if branch.present?
      devices = devices.joins(department: :branch)
                       .where(branches: { name: branch })
    end

    by_type = devices.group(:device_type).count
                     .transform_keys { |k| k.humanize }
                     .sort_by { |_, v| -v }
                     .to_h

    {
      total_devices: by_type.values.sum,
      by_type: by_type,
      filter: { department: department, branch: branch }.compact_blank.presence || "none"
    }
  end
end
