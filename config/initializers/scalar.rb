# frozen_string_literal: true

Scalar.setup do |config|
  config.page_title = "Timevoice API"
  config.configuration = {
    content: Rails.root.join("docs/openapi.yml").read,
    theme: "purple",
    hideDarkModeToggle: false
  }
end
