# config/initializers/ruby_llm.rb

RubyLLM.configure do |config|
  config.gemini_api_key = Rails.application.credentials.dig(:gemini_api_key)
  config.default_model  = "gemini-3.1-flash-lite"
end

# NOTE: The model registry is owned by RubyLLM 2.0 (ruby_llm_models table,
# seeded via `bin/rails ruby_llm:load_models`). Do not seed it from here.
