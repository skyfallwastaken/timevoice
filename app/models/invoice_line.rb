class InvoiceLine < ApplicationRecord
  include CurrencyFormatter

  belongs_to :invoice
  belongs_to :time_entry, optional: true

  validates :description, presence: true
  validates :amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :qty_hours, numericality: { greater_than: 0, less_than: 1000 }, allow_nil: true
  validates :rate_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rate_cents, comparison: {
    less_than_or_equal_to: Invoice::MAX_RATE_CENTS,
    message: "must be at most #{ActiveSupport::NumberHelper.number_to_currency(Invoice::MAX_RATE_CENTS / 100.0)}/hour"
  }, allow_nil: true
  validates :qty_hours, :rate_cents, presence: true, on: :update

  def amount
    amount_cents / 100.0
  end

  def formatted_amount
    format_cents(amount_cents)
  end

  def rate
    rate_cents ? rate_cents / 100.0 : nil
  end

  def formatted_rate
    rate_cents ? format_rate(rate_cents) : nil
  end
end
