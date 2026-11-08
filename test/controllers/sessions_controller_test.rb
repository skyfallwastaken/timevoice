require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "the sign-in page redirects users who are already signed in" do
    sign_in_as users(:one)

    get signin_path

    assert_redirected_to root_path
  end

  test "an invite link opened while signed out is accepted after signing in" do
    invite = Invite.create!(workspace: workspaces(:two), inviter: users(:two), email: users(:one).email)

    get invite_path(token: invite.token)
    assert_redirected_to signin_path

    sign_in_as users(:one)
    assert_redirected_to invite_path(token: invite.token)
  end
end
