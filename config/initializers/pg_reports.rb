PgReports.configure do |config|
  # Telegram (optional)
  # config.telegram_bot_token = ENV["PG_REPORTS_TELEGRAM_TOKEN"]
  # config.telegram_chat_id = ENV["PG_REPORTS_TELEGRAM_CHAT_ID"]

  # Query thresholds
  config.slow_query_threshold_ms = 100        # Queries slower than this
  config.heavy_query_threshold_calls = 1000   # Queries with more calls
  config.expensive_query_threshold_ms = 10000 # Total time threshold

  # Index thresholds
  config.unused_index_threshold_scans = 50    # Index with fewer scans

  # Table thresholds
  config.bloat_threshold_percent = 20         # Tables with more bloat
  config.dead_rows_threshold = 10000          # Dead rows needing vacuum

  # Output settings
  config.max_query_length = 200               # Truncate queries in text output

  # Dashboard authentication (optional)
  config.dashboard_auth = -> {
    authenticate_or_request_with_http_basic do |user, pass|
      user == "admin" && pass == "password"
    end
  }
end
