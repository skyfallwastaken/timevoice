# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator do
    User.find_by(id: session[:user_id]) || redirect_to(signin_url)
  end

  # Use custom OauthApplication model
  application_class "OauthApplication"
  access_token_class "Doorkeeper::AccessToken"
  access_grant_class "Doorkeeper::AccessGrant"

  # Only allow authorization_code flow with PKCE
  grant_flows %w[authorization_code]

  # Force PKCE for non-confidential clients
  force_pkce

  # PKCE code challenge methods (S256 is more secure than plain)
  pkce_code_challenge_methods %w[plain S256]

  # Scopes
  default_scopes :read
  optional_scopes :read, :write, :time_entries, :clients, :projects, :tags, :invoices

  # Enforce configured scopes
  enforce_configured_scopes

  # Token expiration
  access_token_expires_in 2.hours

  # Enable refresh tokens
  use_refresh_token

  # Force SSL only in production
  force_ssl_in_redirect_uri { Rails.env.production? }
end
