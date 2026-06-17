# config/initializers/ruby_llm.rb

RubyLLM.configure do |config|
  config.gemini_api_key = Rails.application.credentials.dig(:gemini_api_key)
  config.default_model  = "gemini-3.1-flash-lite"
  config.use_new_acts_as = true
end

Rails.application.config.after_initialize do
  unless Model.exists?(model_id: "gemini-3.1-flash-lite", provider: "gemini")
    Model.create!(
      model_id: "gemini-3.1-flash-lite",
      provider: "gemini",
      name: "Gemini 3.1 Flash Lite",
      context_window: 1_048_576,
      capabilities: [ "function_calling", "structured_output", "reasoning", "vision" ]
    )
  end
end
