class TimeEntry < ApplicationRecord
  SECONDS_PER_HOUR = 3600
  SECONDS_PER_MINUTE = 60
  MIN_BILLABLE_SECONDS = 36

  belongs_to :user
  belongs_to :workspace
  belongs_to :project, optional: true
  has_many :time_entry_tags, dependent: :destroy
  has_many :tags, through: :time_entry_tags
  has_many :invoice_lines, dependent: :nullify
  has_many :invoices, through: :invoice_lines
  has_many_attached :files

  validates :start_at, presence: true
  validates :description, presence: true, if: :completed?
  validate :file_count_limit
  validates :files, size: { less_than: 10.megabytes, message: "must be less than 10MB" }

  before_save :calculate_duration_seconds, if: :should_calculate_duration?

  MAX_FILES = 3

  scope :running, -> { where(end_at: nil) }
  scope :completed, -> { where.not(end_at: nil) }
  scope :billable, -> { where(billable: true) }
  scope :today, -> { where(start_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(start_at: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :in_date_range, ->(start_date, end_date) { where(start_at: start_date.beginning_of_day..end_date.end_of_day) }
  scope :unbilled, -> {
    completed
      .billable
      .left_outer_joins(:invoice_lines)
      .where(invoice_lines: { id: nil })
      .where(arel_table[:duration_seconds].gteq(MIN_BILLABLE_SECONDS))
  }
  scope :for_client, ->(client) { joins(:project).where(projects: { client_id: client.id }) }

  def running?
    end_at.nil?
  end

  def completed?
    end_at.present?
  end

  def duration
    return nil if running?
    duration_seconds || (end_at - start_at).to_i
  end

  def stop!
    return false unless running?

    update!(
      end_at: Time.current,
      duration_seconds: (Time.current - start_at).to_i
    )
  end

  def formatted_duration
    return nil if duration.nil?

    hours = duration / SECONDS_PER_HOUR
    minutes = (duration % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
    seconds = duration % SECONDS_PER_MINUTE

    if hours > 0
      "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end

  def duration_hours
    (duration_seconds || 0) / SECONDS_PER_HOUR.to_f
  end

  def tag_names
    tags.pluck(:name)
  end

  def billable?
    billable || (project&.billable_default || false)
  end

  private

  def file_count_limit
    if files.attached? && files.count > MAX_FILES
      errors.add(:files, "can only have up to #{MAX_FILES} files")
    end
  end

  def should_calculate_duration?
    end_at.present? && start_at.present? && (end_at_changed? || start_at_changed? || duration_seconds.nil?)
  end

  def calculate_duration_seconds
    self.duration_seconds = (end_at - start_at).to_i
  end
end
