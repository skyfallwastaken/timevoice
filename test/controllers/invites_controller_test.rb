require "test_helper"

class InvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:two)
    @invite = @workspace.invites.create!(email: users(:one).email, inviter: users(:two))
    sign_in_as users(:one)
  end

  test "accepting an invite joins the workspace and redirects to it" do
    post "/invite/#{@invite.token}/accept"

    assert_redirected_to "/#{@workspace.hashid}"
    assert @workspace.member?(users(:one))
  end

  test "opening an invite to a workspace you're already in redirects to it" do
    Membership.create!(workspace: @workspace, user: users(:one), role: "member")

    get "/invite/#{@invite.token}"

    assert_redirected_to "/#{@workspace.hashid}"
  end
end
