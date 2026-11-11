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
  has_many :invoice_lines, dependent: :delete_all
  has_many :time_entries, through: :invoice_lines, source: :time_entry

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :issued_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :status, exclusion: { in: [ STATUS_DRAFT ], message: "can't go back to draft from paid. Mark it unpaid first" }, on: :update, if: -> { status_changed? && status_was == STATUS_PAID }
  validate :number_editable_only_on_drafts, on: :update, if: :invoice_number_changed?
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

  def period_label
    "#{period_start.strftime('%b %d, %Y')} - #{period_end.strftime('%b %d, %Y')}"
  end

  def filename(extension)
    "Invoice to #{client.name} - #{period_label}.#{extension}"
  end

  def self.generate_from_time_entries(workspace, client, period_start_date, period_end_date, rate_cents, user = nil)
    entries = TimeEntry
      .where(workspace: workspace)
      .unbilled
      .for_client(client)

    entries = entries.in_date_range(period_start_date, period_end_date) if period_start_date && period_end_date
    entries = entries.where(user: user) if user
    entries = entries.to_a

    return nil if entries.empty?

    transaction do
      invoice = create!(
        workspace: workspace,
        client: client,
        period_start: period_start_date || entries.map(&:start_at).min.to_date,
        period_end: period_end_date || entries.map(&:start_at).max.to_date,
        issued_on: Date.current,
        status: STATUS_DRAFT,
        total_cents: 0,
        notes: workspace.invoice_setting&.notes
      )

      lines = entries.map do |entry|
        hours = entry.invoice_hours.to_d

        InvoiceLine.new(
          invoice: invoice,
          time_entry: entry,
          description: entry.description,
          qty_hours: hours,
          rate_cents: rate_cents,
          amount_cents: (hours * rate_cents).round
        ).tap(&:validate!)
      end

      lines.each_slice(1000) do |batch|
        InvoiceLine.insert_all!(batch.map { |line| line.attributes.except("id", "created_at", "updated_at") })
      end
      invoice.update!(total_cents: lines.sum(&:amount_cents))
      invoice
    end
  end

  def update_line(line, attributes)
    change_line(line) do
      line.assign_attributes(attributes)
      line.amount_cents = (line.qty_hours * line.rate_cents).round if line.qty_hours && line.rate_cents
      line.save
    end
  end

  # The removed line's time entry becomes unbilled again.
  def remove_line(line)
    change_line(line) do
      if invoice_lines.count == 1
        line.errors.add(:base, "An invoice needs at least one line. Delete the invoice instead.")
        false
      else
        line.destroy
      end
    end
  end

  private

  def number_editable_only_on_drafts
    errors.add(:invoice_number, "can only be changed on a draft") unless status_was == STATUS_DRAFT
  end

  def ensure_draft
    return if self.class.lock.where(id: id).pick(:status) == STATUS_DRAFT

    errors.add(:base, "Only draft invoices can be deleted")
    throw :abort
  end

  # Re-reads the status under a lock so a concurrent issue can't slip past the draft check.
  def change_line(line)
    transaction do
      lock!
      unless status == STATUS_DRAFT
        line.errors.add(:base, "Only draft invoices can be edited")
        raise ActiveRecord::Rollback
      end
      raise ActiveRecord::Rollback unless yield

      update!(total_cents: invoice_lines.sum(:amount_cents))
    end || false
  end

  def stamp_issued_on
    self.issued_on = Date.current
  end

  def set_invoice_number
    self.invoice_number = (workspace.invoices.maximum(:invoice_number) || 0) + 1
  end
end
