class Client < ApplicationRecord
  include Displayable
  extend Hashidable::ClassMethods

  belongs_to :workspace
  has_many :projects, dependent: :nullify
  has_many :invoices, dependent: :restrict_with_error

  normalizes :email, with: ->(email) { email.split(/[,;\s]+/).compact_blank.join(", ").presence }

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validate :email_addresses_valid

  private

  def email_addresses_valid
    invalid = email.to_s.split(", ").reject { |address| address.match?(URI::MailTo::EMAIL_REGEXP) }
    errors.add(:email, "contains an invalid address: #{invalid.first}") if invalid.any?
  end
end
