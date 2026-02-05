class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create, :failure ]
  skip_before_action :require_workspace, only: [ :new, :create, :failure, :destroy ]

  layout "auth"

  def new
    redirect_to root_path if current_user
    render inertia: "Sessions/New"
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)
    user.create_default_workspace if user.workspaces.empty?

    session[:user_id] = user.id
    session[:workspace_id] = user.current_workspace&.id

    if (oauth_return_to = session.delete(:oauth_return_to))
      redirect_to oauth_return_to
      return
    end

    if (token = session.delete(:pending_invite_token))
      invite = Invite.valid.find_by(token: token)
      if invite && invite.email.downcase == user.email.downcase
        redirect_to invite_path(token: invite.token), notice: "Signed in! Review your invitation below."
        return
      end
    end

    redirect_to root_path, notice: "Signed in successfully!"
  end

  def destroy
    reset_session
    flash[:notice] = "Signed out successfully!"
    inertia_location signin_path
  end

  def failure
    redirect_to signin_path, alert: "Authentication failed. Please try again."
  end
end
