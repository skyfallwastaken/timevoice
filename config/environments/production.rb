require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false

  config.eager_load = true

  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true

  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  config.active_storage.service = :local

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  config.cache_store = :solid_cache_store

  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  config.action_mailer.default_url_options = { host: Rails.app.creds.require(:host) }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: Rails.app.creds.require(:smtp, :address),
    port: Rails.app.creds.option(:smtp, :port, default: 587),
    user_name: Rails.app.creds.require(:smtp, :user_name),
    password: Rails.app.creds.require(:smtp, :password),
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false

  config.active_record.attributes_for_inspect = [ :id ]

  config.session_store :cookie_store,
    key: "_timevoice_session",
    secure: true,
    httponly: true,
    same_site: :lax

  config.hosts = [
    Rails.app.creds.require(:host)
  ]

  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
