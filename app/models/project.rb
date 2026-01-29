class Project < ApplicationRecord
  belongs_to :workspace
  belongs_to :client, optional: true
  has_many :time_entries, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }

  GRUVBOX_COLORS = %w[
    #cc241d #98971a #d79921 #458588 #b16286 #689d6a #d65d0e
    #fb4934 #b8bb26 #fabd2f #83a598 #d3869b #8ec07c #fe8019
  ].freeze

  def self.default_color
    GRUVBOX_COLORS.sample
  end

  def display_name
    client ? "#{client.name}: #{name}" : name
  end
end
