class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include InertiaRails::Controller

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :require_workspace
  before_action :set_current_workspace

  inertia_share auth: -> {
    {
      user: current_user&.as_json(only: [ :id, :name, :email, :avatar_url, :timezone ]),
      workspace: current_workspace&.as_json(only: [ :id, :name ], methods: [ :hashid ]),
      workspaces: current_user&.workspaces&.order(:name)&.map { |w| { id: w.id, name: w.name, hashid: w.hashid } } || []
    }
  }

  inertia_share flash: -> {
    {
      notice: flash[:notice],
      alert: flash[:alert]
    }
  }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def authenticate_user!
    return if current_user

    redirect_to signin_path, alert: "Please sign in to continue."
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  helper_method :current_user

  def current_workspace
    @current_workspace ||= begin
      if params[:workspace_id].present?
        # Decode hashid to get the numeric ID
        workspace_id = Workspace.decode_id(params[:workspace_id])
        current_user&.workspaces&.find_by(id: workspace_id)
      elsif session[:workspace_id]
        current_user&.workspaces&.find_by(id: session[:workspace_id])
      else
        current_user&.workspaces&.first
      end
    end
  end

  helper_method :current_workspace

  def pundit_user
    current_user
  end

  def set_current_workspace
    return unless current_user && current_workspace

    session[:workspace_id] = current_workspace.id

    # Save last used workspace for the user
    if current_user.last_used_workspace_id != current_workspace.id
      current_user.update_column(:last_used_workspace_id, current_workspace.id)
    end
  end

  def require_workspace
    return unless current_user

    # If at root path, redirect to last used workspace timer or first workspace
    if request.path == "/"
      target_workspace = current_user.last_used_workspace || current_user.workspaces.first
      if target_workspace
        redirect_to "/#{target_workspace.hashid}/timer"
        return
      else
        redirect_to signin_path, alert: "No workspace found. Please contact support."
        return
      end
    end

    return if current_workspace

    if current_user.workspaces.any?
      first_workspace = current_user.workspaces.first
      session[:workspace_id] = first_workspace.id
    else
      redirect_to signin_path, alert: "No workspace found. Please contact support."
    end
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  # Helper for permitting parameters that may or may not be wrapped in a key
  def optional_params(key, *fields)
    if params[key].present?
      params.require(key).permit(*fields)
    else
      params.permit(*fields)
    end
  end
end
