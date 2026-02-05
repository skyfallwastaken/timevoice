class Oauth::AuthorizationsController < Doorkeeper::AuthorizationsController
  include InertiaRails::Controller

  layout "application"

  before_action :authenticate_resource_owner!

  def new
    if pre_auth.authorizable?
      if skip_authorization? || matching_token?
        auth = authorization.authorize
        redirect_or_render auth
      else
        render_authorize_form
      end
    else
      render_error
    end
  end

  private

  def render_authorize_form
    render inertia: "OAuth/Authorize", props: {
      application: {
        name: pre_auth.client.application.name,
        trust_level: pre_auth.client.application.trust_level,
        owner_name: pre_auth.client.application.workspace.name
      },
      client_id: pre_auth.client.uid,
      scopes: requested_scopes_with_descriptions,
      response_type: pre_auth.response_type,
      redirect_uri: pre_auth.redirect_uri,
      state: pre_auth.state,
      code_challenge: params[:code_challenge],
      code_challenge_method: params[:code_challenge_method]
    }
  end

  def render_error
    if pre_auth.error == :invalid_redirect_uri
      render inertia: "OAuth/Error", props: {
        error: "Invalid redirect URI",
        message: "The application provided an invalid redirect URI."
      }
    else
      error_response = pre_auth.error_response
      render inertia: "OAuth/Error", props: {
        error: pre_auth.error.to_s.humanize,
        message: error_response.try(:description) || "Authorization request failed."
      }
    end
  end

  def requested_scopes_with_descriptions
    pre_auth.scopes.map do |scope|
      scope_info = OauthApplication::SCOPES[scope.to_sym]
      {
        name: scope.to_s,
        title: scope_info&.dig(:title) || scope.to_s.humanize,
        description: scope_info&.dig(:description) || scope.to_s
      }
    end
  end

  def authenticate_resource_owner!
    unless current_resource_owner
      store_location_for_oauth
      redirect_to signin_path
    end
  end

  def store_location_for_oauth
    session[:oauth_return_to] = request.fullpath
  end

  def current_resource_owner
    @current_resource_owner ||= User.find_by(id: session[:user_id])
  end

  def skip_authorization?
    pre_auth.client.application.official?
  end
end
