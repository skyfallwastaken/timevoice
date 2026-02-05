class Invoice < ApplicationRecord
  include Hashidable
  include CurrencyFormatter

  STATUSES = %w[draft issued paid].freeze
  STATUS_DRAFT = "draft".freeze
  STATUS_ISSUED = "issued".freeze
  STATUS_PAID = "paid".freeze

  belongs_to :workspace
  belongs_to :client
  has_many :invoice_lines, dependent: :destroy
  has_many :time_entries, through: :invoice_lines, source: :time_entry

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :issued_on, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :draft, -> { where(status: STATUS_DRAFT) }
  scope :issued, -> { where(status: STATUS_ISSUED) }
  scope :paid, -> { where(status: STATUS_PAID) }

  def total_amount
    total_cents / 100.0
  end

  def formatted_total
    format_cents(total_cents)
  end

  def self.generate_from_time_entries(workspace, client, period_start_date, period_end_date, rate_cents, user = nil)
    entries_query = TimeEntry
      .where(workspace: workspace)
      .unbilled
      .for_client(client)
      .in_date_range(period_start_date, period_end_date)

    entries_query = entries_query.where(user: user) if user

    entries = entries_query

    return nil if entries.empty?

    invoice = create!(
      workspace: workspace,
      client: client,
      period_start: period_start_date,
      period_end: period_end_date,
      issued_on: Date.current,
      status: STATUS_DRAFT,
      total_cents: 0
    )

    total = 0

    entries.each do |entry|
      hours = entry.duration_hours
      amount = (hours * rate_cents).round

      InvoiceLine.create!(
        invoice: invoice,
        time_entry: entry,
        description: entry.description,
        qty_hours: hours,
        rate_cents: rate_cents,
        amount_cents: amount
      )

      total += amount
    end

    invoice.update!(total_cents: total)
    invoice
  end
end
