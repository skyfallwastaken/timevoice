require "test_helper"

class DocsControllerTest < ActionDispatch::IntegrationTest
  test "the API reference links back to the app without signing in" do
    get "/docs"

    assert_response :success
    assert_select "header a[href=?]", "/", text: "← Back to Timevoice"
    assert_includes response.body, "Scalar.createApiReference"
    assert_includes response.body, %("showDeveloperTools":"never")
  end
end
