class InvoiceLine < ApplicationRecord
  include CurrencyFormatter

  belongs_to :invoice
  belongs_to :time_entry, optional: true

  validates :description, presence: true
  validates :amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :qty_hours, numericality: { greater_than: 0 }, allow_nil: true

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
