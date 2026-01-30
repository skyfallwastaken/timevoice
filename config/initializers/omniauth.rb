Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.app.creds.google.client_id,
    Rails.app.creds.google.client_secret,
    {
      scope: "email,profile",
      prompt: "select_account",
      image_aspect_ratio: "square",
      image_size: 200,
      name: "google_oauth2"
    }
end

OmniAuth.config.allowed_request_methods = [ :get, :post ]
OmniAuth.config.silence_get_warning = true
