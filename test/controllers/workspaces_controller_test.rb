require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  test "a user with no workspace can create one" do
    user = users(:one)
    sign_in_as user
    user.memberships.destroy_all

    assert_difference -> { user.workspaces.count } do
      post "/workspaces", params: { workspace: { name: "Fresh start" } }
    end

    workspace = user.workspaces.sole
    assert_equal "Fresh start", workspace.name
    assert_redirected_to "/#{workspace.hashid}/timer"
  end
end
