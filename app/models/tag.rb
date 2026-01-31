class Tag < ApplicationRecord
  include Displayable

  belongs_to :workspace
  has_many :time_entry_tags, dependent: :destroy
  has_many :time_entries, through: :time_entry_tags

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
end
