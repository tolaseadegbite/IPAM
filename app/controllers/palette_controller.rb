class PaletteController < ApplicationController
  COMMANDS = [
    { icon: "chart-pie", label: "Go to Dashboard", keywords: "home dashboard", url: :dashboard_path },
    { icon: "monitor", label: "Go to Devices", keywords: "devices assets inventory", url: :devices_path },
    { icon: "network", label: "Go to Subnets", keywords: "subnets network cidr vlan", url: :subnets_path },
    { icon: "map-pinned", label: "Go to IP Addresses", keywords: "ip addresses", url: :ip_addresses_path },
    { icon: "building", label: "Go to Branches", keywords: "branches offices", url: :branches_path },
    { icon: "kanban", label: "Go to Operations", keywords: "operations boards tasks kanban", url: :boards_path },
    { icon: "message-square-text", label: "New NAT chat", keywords: "assistant chat nat", url: :new_chat_path },
    { icon: "monitor", label: "New Device", keywords: "new device create onboard", url: :new_device_path },
    { icon: "bell", label: "Go to Notifications", keywords: "notifications alerts bell", url: :notifications_path }
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
      next unless "#{command[:label]} #{command[:keywords]}".downcase.include?(query.downcase)

      command.except(:keywords).merge(url: send(command[:url]))
    end
  end

  def matching_records(query)
    pattern = "%#{query.gsub(/[%_]/, "")}%"
    results = []
    results += Device.where("name ILIKE ?", pattern).order(:name).limit(RESULT_LIMIT).map do |device|
      { icon: "monitor", label: device.name, sub: device.department&.name, url: device_path(device) }
    end
    results += Subnet.where("name ILIKE ?", pattern).order(:name).limit(RESULT_LIMIT).map do |subnet|
      { icon: "network", label: subnet.name, sub: subnet.network_address.to_s, url: subnet_path(subnet) }
    end
    results += Branch.where("name ILIKE ?", pattern).order(:name).limit(RESULT_LIMIT).map do |branch|
      { icon: "building", label: branch.name, sub: branch.location, url: branch_path(branch) }
    end
    results
  end
end
