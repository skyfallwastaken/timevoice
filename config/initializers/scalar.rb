# frozen_string_literal: true

Scalar.setup do |config|
  config.specification = Rails.root.join("docs/openapi.yml").read
  config.page_title = "Timevoice API"
  config.scalar_configuration = {
    theme: "purple",
    hideDarkModeToggle: false
  }
end
