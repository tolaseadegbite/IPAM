ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def sign_in_as(user)
    post(sign_in_url, params: { username: user.username, password: "Secret1*3*5*" }); user
  end
end

# RubyLLM 2.0 owns its model registry (ruby_llm_models table). Fresh test
# databases (CI, new clones) have zero rows, which breaks anything listing
# chat models. Seed from the packaged registry when empty (~3s, upsert-safe
# under parallel workers).
if RubyLLM.models.chat_models.all.empty?
  system("bin/rails ruby_llm:load_models") || raise("Failed to seed RubyLLM model registry for tests")
end
