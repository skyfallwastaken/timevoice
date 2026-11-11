require "test_helper"

class Oauth::AuthorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "an unknown client shows a readable error title" do
    get "/oauth/authorize", params: { client_id: "missing", response_type: "code", redirect_uri: "http://localhost/cb" }

    assert_response :success
    assert_equal "Invalid client", inertia_props["error"]
  end
end
