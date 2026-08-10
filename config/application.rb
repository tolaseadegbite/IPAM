require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Ipam
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    config.mission_control.jobs.base_controller_class = "MissionControlController"
    config.solid_queue.clear_finished_jobs_after = 14.days
    config.eager_load_paths << Rails.root.join("app/services")
    config.eager_load_paths << Rails.root.join("app/tools")
    config.eager_load_paths << Rails.root.join("app/agents")

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.active_record.yaml_column_permitted_classes = [
      Symbol,
      Date,
      Time,
      ActiveSupport::TimeWithZone,
      ActiveSupport::TimeZone
    ]

    # pg_reports
    config.active_record.query_log_tags_enabled = true
    config.active_record.query_log_tags = [ :controller, :action ]
  end
end
