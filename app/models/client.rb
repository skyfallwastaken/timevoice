class Client < ApplicationRecord
  belongs_to :workspace
  has_many :projects, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :workspace_id }

  def display_name
    name
  end
end
