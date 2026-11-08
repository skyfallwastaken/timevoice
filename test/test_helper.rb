ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Build the Vite test assets once here, before parallel workers fork; otherwise
# each worker's first page render starts its own build and they race on
# public/vite-test (missing manifest, "Directory not empty").
ViteRuby.commands.build || abort("Vite build failed")

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: user.google_uid,
      info: { name: user.name, email: user.email }
    )
    get "/auth/google_oauth2/callback"
  end

  def inertia_props
    JSON.parse(response.body[%r{<script data-page="app" type="application/json">(.*?)</script>}m, 1])["props"]
  end
end
