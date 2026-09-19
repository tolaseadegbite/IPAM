require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
    # Never hit the network in tests: stub the registry refresh.
    refresh_method = RubyLLM.models.method(:refresh)
    RubyLLM.models.define_singleton_method(:refresh) { |*| true }
    @restore_refresh = -> { RubyLLM.models.define_singleton_method(:refresh) { |*args| refresh_method.call(*args) } }
  end

  teardown do
    @restore_refresh.call
  end

  test "admin refresh returns to chats index when referred from there" do
    post refresh_models_path, headers: { "Referer" => chats_url }

    assert_redirected_to chats_url
    assert_equal "Models refreshed successfully", flash[:notice]
  end

  test "admin refresh falls back to models index without referrer" do
    post refresh_models_path

    assert_redirected_to models_url
  end

  test "non-admin refresh is bounced" do
    users(:lazaro_nixon).update!(admin: false)

    post refresh_models_path

    assert_redirected_to root_url
  end
end
