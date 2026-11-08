class Invoice < ApplicationRecord
  include Hashidable
  include CurrencyFormatter

  STATUSES = %w[draft issued paid].freeze
  STATUS_DRAFT = "draft".freeze
  STATUS_ISSUED = "issued".freeze
  STATUS_PAID = "paid".freeze
  # $10,000/hour keeps line amounts within the integer columns.
  MAX_RATE_CENTS = 1_000_000

  belongs_to :workspace
  belongs_to :client
  has_many :invoice_lines, dependent: :destroy
  has_many :time_entries, through: :invoice_lines, source: :time_entry

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :issued_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :invoice_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :workspace_id }, on: :update

  scope :draft, -> { where(status: STATUS_DRAFT) }
  scope :issued, -> { where(status: STATUS_ISSUED) }
  scope :paid, -> { where(status: STATUS_PAID) }

  before_create :set_invoice_number
  # Deleting an issued or paid invoice would make its entries billable again.
  # Runs before the lines are destroyed; re-reads the status under a lock so a
  # concurrent issue can't slip past it.
  before_destroy :ensure_draft, prepend: true, unless: :destroyed_by_association
  before_save :stamp_issued_on, if: -> { status_changed? && status_was == STATUS_DRAFT }

  def total_amount
    total_cents / 100.0
  end

  def formatted_total
    format_cents(total_cents)
  end

  def self.generate_from_time_entries(workspace, client, period_start_date, period_end_date, rate_cents, user = nil)
    entries = TimeEntry
      .where(workspace: workspace)
      .unbilled
      .for_client(client)

    entries = entries.in_date_range(period_start_date, period_end_date) if period_start_date && period_end_date
    entries = entries.where(user: user) if user

    return nil if entries.empty?

    transaction do
      invoice = create!(
        workspace: workspace,
        client: client,
        period_start: period_start_date || entries.minimum(:start_at).to_date,
        period_end: period_end_date || entries.maximum(:start_at).to_date,
        issued_on: Date.current,
        status: STATUS_DRAFT,
        total_cents: 0,
        notes: workspace.invoice_setting&.notes
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

  private

  def ensure_draft
    return if self.class.lock.where(id: id).pick(:status) == STATUS_DRAFT

    errors.add(:base, "Only draft invoices can be deleted")
    throw :abort
  end

  def stamp_issued_on
    self.issued_on = Date.current
  end

  def set_invoice_number
    self.invoice_number = (workspace.invoices.maximum(:invoice_number) || 0) + 1
  end
end
