class DocsController < ApplicationController
  PAGES = {
    "welcome" => "Welcome to Mainline",
    "dashboard" => "Dashboard",
    "organization" => "Branches, Departments & People",
    "devices" => "Devices",
    "subnets" => "Subnets",
    "ip-addresses" => "IP Addresses",
    "scanning" => "Network Scanning",
    "boards" => "Boards & Tasks",
    "assistant" => "NAT Assistant",
    "search" => "Search",
    "api" => "API Reference",
    "notifications" => "Notifications",
    "account" => "Account & Security",
    "admin" => "Administration",
    "appearance" => "Appearance & Themes",
    "faq" => "FAQ & Troubleshooting"
  }.freeze

  def index
    redirect_to doc_page_path("welcome")
  end

  def show
    @slug = params[:page].to_s
    @title = PAGES.fetch(@slug) { raise ActiveRecord::RecordNotFound }

    path = Rails.root.join("docs", "#{@slug}.md")
    raise ActiveRecord::RecordNotFound unless File.file?(path)

    @body = File.read(path)

    keys = PAGES.keys
    index = keys.index(@slug)
    @prev_slug = keys[index - 1] if index.positive?
    @next_slug = keys[index + 1]
  end
end
