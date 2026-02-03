# Since we protect /jobs with a route constraint requiring admin?,
# disable MissionControl's built-in HTTP Basic authentication
Rails.application.configure do
  config.mission_control.jobs.http_basic_auth_enabled = false
end
