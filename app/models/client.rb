class Client < ApplicationRecord
  include Displayable

  belongs_to :workspace
  has_many :projects, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
end
