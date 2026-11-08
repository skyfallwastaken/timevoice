class Project < ApplicationRecord
  extend Hashidable::ClassMethods

  belongs_to :workspace
  belongs_to :client, optional: true
  has_many :time_entries, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
  validate :client_in_workspace, if: :client_id_changed?

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

  def as_props
    as_json(only: [ :id, :name, :color, :billable_default ], include: { client: { only: [ :id, :name ] } })
  end

  private

  def client_in_workspace
    return unless client

    same = workspace_id && client.workspace_id ? client.workspace_id == workspace_id : client.workspace == workspace
    errors.add(:client, "must belong to this workspace") unless same
  end
end
