class InvoiceSetting < ApplicationRecord
  include CurrencyFormatter

  belongs_to :workspace

  validates :billable_rate_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sender_name, presence: true
  validates :workspace_id, uniqueness: true

  def billable_rate
    billable_rate_cents / 100.0
  end

  def formatted_rate
    format_cents(billable_rate_cents)
  end
end
