class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include InertiaRails::Controller

  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :require_workspace
  before_action :set_current_workspace
  around_action :use_user_time_zone

  inertia_share auth: -> {
    {
      user: current_user&.as_json(only: [ :id, :name, :email, :avatar_url, :timezone, :theme ]),
      workspace: current_workspace&.as_json(only: [ :id, :name ], methods: [ :hashid ]),
      workspaces: current_user&.workspaces&.order(:name)&.map { |w| { id: w.id, name: w.name, hashid: w.hashid } } || [],
      is_admin: current_user&.admin? || false
    }
  }

  inertia_share flash: -> {
    {
      notice: flash[:notice],
      alert: flash[:alert],
      new_secret: flash[:new_secret],
      secret_app_id: flash[:secret_app_id]
    }
  }

  inertia_share runningEntry: -> { running_entry_json }

  inertia_share rails_env: -> {
    Rails.env.to_s
  }

  inertia_share csrf_token: -> {
    form_authenticity_token
  }

  inertia_share turnstile_site_key: -> {
    Rails.app.creds.require(:cloudflare, :turnstile_site_key)
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

  def current_theme
    Theme.find(current_user&.theme)
  end

  helper_method :current_theme

  def pundit_user
    UserContext.new(current_user, current_workspace)
  end

  def set_current_workspace
    return unless current_user && current_workspace

    session[:workspace_id] = current_workspace.id

    if current_user.last_used_workspace_id != current_workspace.id
      current_user.update_column(:last_used_workspace_id, current_workspace.id)
    end
  end

  def require_workspace
    return unless current_user

    if request.path == "/"
      target_workspace = current_user.default_workspace
      if target_workspace
        redirect_to workspace_timer_path(target_workspace)
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
      redirect_to workspace_timer_path(first_workspace)
    else
      redirect_to signin_path, alert: "No workspace found. Please contact support."
    end
  end

  def use_user_time_zone(&)
    browser_zone = cookies[:tz] if cookies[:tz].present? && ActiveSupport::TimeZone[cookies[:tz]]

    if current_user && browser_zone && current_user.timezone != browser_zone
      current_user.update_column(:timezone, browser_zone)
    end

    Time.use_zone(browser_zone || current_user&.timezone || "UTC", &)
  end

  # No limit, so eager loading the tags stays a single query; there is at
  # most one running entry per user and workspace.
  def running_entry_json
    return unless current_user && current_workspace

    policy_scope(TimeEntry).running
      .eager_load(:project, :tags).order(:start_at).to_a.last
      &.as_json(
        only: [ :id, :description, :start_at, :billable ],
        include: {
          project: { only: [ :id, :name, :color ] },
          tags: { only: [ :id, :name ] }
        }
      )
  end

  def redirect_with_error(location, message, field: :base)
    redirect_to location, alert: message, inertia: { errors: { field => message } }
  end

  def redirect_with_record_errors(location, record)
    redirect_to location, alert: record.errors.full_messages.join(", "), inertia: { errors: record.errors }
  end

  def redirect_back_with_record_errors(record, fallback_location: root_path)
    redirect_back fallback_location: fallback_location, alert: record.errors.full_messages.join(", "), inertia: { errors: record.errors }
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  def optional_params(key, *fields)
    if params[key].present?
      params.require(key).permit(*fields)
    else
      params.permit(*fields)
    end
  end
end
