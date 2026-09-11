class PaletteController < ApplicationController
  COMMANDS = [
    { icon: "chart-pie", label: "Go to Dashboard (Ctrl + Shift + Y)", keywords: "home dashboard", url: :dashboard_path, section: "Commands" },
    { icon: "monitor", label: "Go to Devices", keywords: "devices assets inventory", url: :devices_path, section: "Commands" },
    { icon: "network", label: "Go to Subnets", keywords: "subnets network cidr vlan", url: :subnets_path, section: "Commands" },
    { icon: "map-pinned", label: "Go to IP Addresses (Ctrl + Shift + U)", keywords: "ip addresses", url: :ip_addresses_path, section: "Commands" },
    { icon: "building", label: "Go to Branches", keywords: "branches offices", url: :branches_path, section: "Commands" },
    { icon: "warehouse", label: "Go to Departments", keywords: "departments teams", url: :departments_path, section: "Commands" },
    { icon: "users-round", label: "Go to Employees (Ctrl + Shift + E)", keywords: "employees people staff", url: :employees_path, section: "Commands" },
    { icon: "kanban", label: "Go to Operations (Ctrl + Shift + K)", keywords: "operations boards tasks kanban", url: :boards_path, section: "Commands" },
    { icon: "message-square-text", label: "New NAT chat", keywords: "assistant chat nat", url: :new_chat_path, section: "Commands" },
    { icon: "monitor", label: "New Device", keywords: "new device create onboard", url: :new_device_path, section: "Commands" },
    { icon: "user-check", label: "New Employee", keywords: "new employee onboard hire", url: :new_employee_path, section: "Commands" },
    { icon: "network", label: "New Subnet", keywords: "new subnet create cidr", url: :new_subnet_path, section: "Commands" },
    { icon: "history", label: "Go to History", keywords: "history audit log versions", url: :versions_path, section: "Commands" },
    { icon: "bell", label: "Go to Notifications", keywords: "notifications alerts bell", url: :notifications_path, section: "Commands" },
    { icon: "radar", label: "Scan now", keywords: "scan network sweep refresh discover", url: :scan_dashboard_path, method: :post, section: "Commands" }
  ].freeze

  RESULT_LIMIT = 5

  def index
    query = params[:q].to_s.strip
    results = matching_commands(query)
    results += matching_records(query) if query.present?
    render json: results
  end

  private

  def matching_commands(query)
    COMMANDS.filter_map do |command|
      next command.except(:keywords).merge(url: send(command[:url])) if query.blank?
      # Match the base label (hotkey suffix excluded) plus keywords.
      next unless "#{command[:label].sub(/ \(.*\)$/, "")} #{command[:keywords]}".downcase.include?(query.downcase)

      command.except(:keywords).merge(url: send(command[:url]))
    end
  end

  def matching_records(query)
    pattern = "%#{query.gsub(/[%_]/, "")}%"
    results = []
    results += Device.includes(department: :branch).where("devices.name ILIKE ?", pattern).order(:name).limit(RESULT_LIMIT).map do |device|
      { icon: "monitor", label: device.name, sub: device.department&.name, url: device_path(device), section: "Devices" }
    end
    results += Subnet.where("name ILIKE ?", pattern).order(:name).limit(RESULT_LIMIT).map do |subnet|
      { icon: "network", label: subnet.name, sub: subnet.network_address.to_s, url: subnet_path(subnet), section: "Network" }
    end
    results += Branch.where("name ILIKE ?", pattern).order(:name).limit(RESULT_LIMIT).map do |branch|
      { icon: "building", label: branch.name, sub: branch.location, url: branch_path(branch), section: "Places" }
    end
    results += Department.includes(:branch).where("departments.name ILIKE ?", pattern).order(:name).limit(RESULT_LIMIT).map do |department|
      { icon: "warehouse", label: department.name, sub: department.branch&.name, url: department_path(department), section: "Places" }
    end
    results += Employee.includes(department: :branch).where("first_name ILIKE ? OR last_name ILIKE ?", pattern, pattern).order(:first_name, :last_name).limit(RESULT_LIMIT).map do |employee|
      { icon: "user", label: employee.full_name, sub: employee.department&.name, url: employee_path(employee), section: "People" }
    end
    results += IpAddress.includes(:subnet, :device).where("host(address) ILIKE ?", pattern).order(:address).limit(RESULT_LIMIT).map do |ip|
      { icon: "globe", label: ip.address.to_s, sub: ip.device&.name || ip.subnet&.name, url: ip_address_path(ip), section: "Network" }
    end
    # Cards have no show route: link to the parent board with the list name.
    results += Card.includes(list: :board).where("title ILIKE ?", pattern).order(:title).limit(RESULT_LIMIT).map do |card|
      { icon: "kanban", label: card.title, sub: card.list&.name, url: card.list ? board_path(card.list.board) : boards_path, section: "Tasks" }
    end
    results
  end
end
