# Color themes a user can pick in Settings. Their palettes live in
# app/frontend/assets/themes.css, keyed by the same key.
Theme = Data.define(:key, :name, :family, :mode)

class Theme
  DEFAULT = "daydream-dark"

  ALL = [
    new(key: "daydream-dark", name: "Daydream Dark", family: "Daydream", mode: "dark"),
    new(key: "daydream-light", name: "Daydream Light", family: "Daydream", mode: "light"),
    new(key: "gruvbox-dark", name: "Gruvbox Dark", family: "Gruvbox", mode: "dark"),
    new(key: "gruvbox-light", name: "Gruvbox Light", family: "Gruvbox", mode: "light"),
    new(key: "catppuccin-latte", name: "Catppuccin Latte", family: "Catppuccin", mode: "light"),
    new(key: "catppuccin-frappe", name: "Catppuccin Frappé", family: "Catppuccin", mode: "dark"),
    new(key: "catppuccin-macchiato", name: "Catppuccin Macchiato", family: "Catppuccin", mode: "dark"),
    new(key: "catppuccin-mocha", name: "Catppuccin Mocha", family: "Catppuccin", mode: "dark"),
    new(key: "nord", name: "Nord", family: "More", mode: "dark"),
    new(key: "dracula", name: "Dracula", family: "More", mode: "dark"),
    new(key: "tokyo-night", name: "Tokyo Night", family: "More", mode: "dark"),
    new(key: "rose-pine", name: "Rosé Pine", family: "More", mode: "dark"),
    new(key: "rose-pine-dawn", name: "Rosé Pine Dawn", family: "More", mode: "light")
  ].freeze

  def self.all
    ALL
  end

  def self.keys
    ALL.map(&:key)
  end

  def self.find(key)
    ALL.find { |theme| theme.key == key } || ALL.find { |theme| theme.key == DEFAULT }
  end
end
