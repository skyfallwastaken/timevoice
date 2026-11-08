class Client < ApplicationRecord
  include Displayable
  extend Hashidable::ClassMethods

  belongs_to :workspace
  has_many :projects, dependent: :nullify
  has_many :invoices, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
end
