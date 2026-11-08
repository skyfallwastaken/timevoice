# frozen_string_literal: true

# Rendered by DocsController at /docs, which wraps the reference in a header
# that links back to the app.
Scalar.setup do |config|
  config.page_title = "Timevoice API"
  config.configuration = {
    content: Rails.root.join("docs/openapi.yml").read,
    theme: "purple",
    forceDarkModeState: "dark",
    hideDarkModeToggle: true,
    showDeveloperTools: "never",
    agent: { disabled: true },
    customCss: <<~CSS
      .dark-mode {
        --scalar-background-1: #131613;
        --scalar-background-2: #1b1f1b;
        --scalar-background-3: #2f372f;
        --scalar-border-color: #2f372f;
        --scalar-color-1: #e1e7e0;
        --scalar-color-2: #ccccc9;
        --scalar-color-3: #9ca49c;
        --scalar-color-accent: #d5b5ff;
      }
    CSS
  }
end
