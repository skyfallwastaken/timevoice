class TimeEntry < ApplicationRecord
  belongs_to :user
  belongs_to :workspace
  belongs_to :project, optional: true
  has_many :time_entry_tags, dependent: :destroy
  has_many :tags, through: :time_entry_tags
  has_many :invoice_lines, dependent: :nullify
  has_many :invoices, through: :invoice_lines

  validates :start_at, presence: true
  validates :description, presence: true, if: :completed?

  scope :running, -> { where(end_at: nil) }
  scope :completed, -> { where.not(end_at: nil) }
  scope :billable, -> { where(billable: true) }
  scope :today, -> { where(start_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(start_at: Time.current.beginning_of_week..Time.current.end_of_week) }

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

    hours = duration / 3600
    minutes = (duration % 3600) / 60
    seconds = duration % 60

    if hours > 0
      "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end

  def tag_names
    tags.pluck(:name)
  end

  def billable?
    billable || (project&.billable_default || false)
  end
end
