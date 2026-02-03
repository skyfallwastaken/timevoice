# Use AdminController for authentication instead of HTTP Basic auth
Rails.application.configure do
  config.mission_control.jobs.base_controller_class = "AdminController"
  config.mission_control.jobs.http_basic_auth_enabled = false
end
