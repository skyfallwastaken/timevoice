require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Timevoice
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.autoload_paths << Rails.root.join("app/services")
    config.eager_load_paths << Rails.root.join("app/services")
  end
end
