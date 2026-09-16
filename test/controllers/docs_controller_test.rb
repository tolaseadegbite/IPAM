require "test_helper"

class DocsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:lazaro_nixon)
  end

  test "should redirect index to welcome" do
    get docs_url
    assert_redirected_to doc_page_url("welcome")
  end

  test "should render every doc page" do
    DocsController::PAGES.each_key do |slug|
      get doc_page_url(slug)
      assert_response :success
      assert_select "article h1", DocsController::PAGES.fetch(slug)
      assert_select "nav[aria-label='Documentation']"
    end
  end

  test "should link docs from the sidebar" do
    get dashboard_url
    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href='#{docs_path}']", text: "Docs"
  end

  test "should 404 unknown slugs" do
    get doc_page_url("nope-not-a-page")
    assert_response :not_found
  end

  test "should require sign in" do
    delete session_url(users(:lazaro_nixon).sessions.last)

    get docs_url
    assert_redirected_to sign_in_url
  end
end
