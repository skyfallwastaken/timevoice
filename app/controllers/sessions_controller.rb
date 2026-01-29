class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create, :failure ]
  skip_before_action :require_workspace, only: [ :new, :create, :failure, :destroy ]

  layout "auth"

  def new
    redirect_to root_path if current_user
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)
    user.create_default_workspace if user.workspaces.empty?

    session[:user_id] = user.id
    session[:workspace_id] = user.current_workspace&.id

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
