# frozen_string_literal: true

Rails.application.config.to_prepare do
  Turnstiled.site_key = Rails.app.creds.require(:cloudflare, :turnstile_site_key)
  Turnstiled.site_secret = Rails.app.creds.require(:cloudflare, :turnstile_secret_key)
  Turnstiled.mock = false  # Use real Cloudflare verification, not mock mode
end
