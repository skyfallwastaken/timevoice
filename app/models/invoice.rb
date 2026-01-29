class Invoice < ApplicationRecord
  include Hashidable
  include CurrencyFormatter

  belongs_to :workspace
  belongs_to :client
  has_many :invoice_lines, dependent: :destroy
  has_many :time_entries, through: :invoice_lines, source: :time_entry

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :issued_on, presence: true
  validates :status, inclusion: { in: %w[draft issued paid] }

  scope :draft, -> { where(status: "draft") }
  scope :issued, -> { where(status: "issued") }
  scope :paid, -> { where(status: "paid") }

  def total_amount
    total_cents / 100.0
  end

  def formatted_total
    format_cents(total_cents)
  end

  def self.generate_from_time_entries(workspace, client, period_start_date, period_end_date, rate_cents, user = nil)
    entries_query = TimeEntry
      .where(workspace: workspace)
      .completed
      .where(billable: true)
      .left_outer_joins(:invoice_lines)
      .where(invoice_lines: { id: nil })
      .joins(:project)
      .where(projects: { client_id: client.id })
      .where(start_at: period_start_date.beginning_of_day..period_end_date.end_of_day)
      .where(TimeEntry.arel_table[:duration_seconds].gt(0))
      .where(TimeEntry.arel_table[:duration_seconds].gteq(36))

      entries_query = entries_query.where(user: user) if user

    entries = entries_query

    return nil if entries.empty?

    invoice = create!(
      workspace: workspace,
      client: client,
      period_start: period_start_date,
      period_end: period_end_date,
      issued_on: Date.current,
      status: "draft",
      total_cents: 0
    )

    total = 0

    entries.each do |entry|
      hours = (entry.duration_seconds || 0) / 3600.0
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
