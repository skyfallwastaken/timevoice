class Workspace < ApplicationRecord
  include Hashidable

  belongs_to :owner, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :time_entries, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :invites, dependent: :destroy
  has_many :oauth_applications, dependent: :destroy
  has_one :invoice_setting, dependent: :destroy

  validates :name, presence: true

  def member?(user)
    memberships.exists?(user: user)
  end

  def admin?(user)
    memberships.exists?(user: user, role: [ "admin", "owner" ])
  end

  def owner?(user)
    owner_id == user.id
  end

  def invoice_settings
    invoice_setting || create_default_invoice_settings
  end

  private

  def create_default_invoice_settings
    InvoiceSetting.create!(
      workspace: self,
      sender_name: owner.name,
      billable_rate_cents: 0
    )
  end
end
