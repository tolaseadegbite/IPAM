require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "creates token and shows secret once" do
    assert_difference "ApiToken.count", 1 do
      post api_tokens_url, params: { api_token: { name: "nightly" } }
    end
    assert_redirected_to account_url
    follow_redirect!

    token = ApiToken.last
    assert_equal "nightly", token.name
    assert_equal 8, token.prefix.length
    assert_not_nil token.token_digest
    assert_response :success
  end

  test "revokes own token" do
    token = users(:lazaro_nixon).api_tokens.create!(name: "old", token_digest: "x", prefix: "y")

    assert_difference "ApiToken.count", -1 do
      delete api_token_url(token)
    end
    assert_redirected_to account_url
  end

  test "cannot revoke another users token" do
    other = User.create!(username: "otherone", email: "other@example.com",
                         password: "Sup3rSecretTemp!", verified: true)
    token = other.api_tokens.create!(name: "theirs", token_digest: "x", prefix: "y")

    assert_no_difference "ApiToken.count" do
      delete api_token_url(token)
    end
    assert_response :not_found
  end

  test "requires sign in" do
    delete session_url(users(:lazaro_nixon).sessions.last)

    post api_tokens_url, params: { api_token: { name: "x" } }
    assert_redirected_to sign_in_url
  end
end
