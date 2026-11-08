class TimeEntry < ApplicationRecord
  extend Hashidable::ClassMethods

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
  validate :end_after_start
  validate :project_in_workspace, if: :project_id_changed?
  validate :one_running_entry, if: :running?
  validates :files, size: { less_than: 10.megabytes, message: "must be less than 10MB" }

  before_save :calculate_duration_seconds, if: :should_calculate_duration?

  MAX_FILES = 3

  scope :running, -> { where(end_at: nil) }
  scope :completed, -> { where.not(end_at: nil) }
  scope :billable, -> { where(billable: true) }
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

  def stop!(at: nil)
    return false unless running?

    ended = [ [ at || Time.current, Time.current ].min, start_at ].max
    # Stopping only sets the end, so other fields (a timer started without a
    # description, older data) can't block it.
    update_columns(end_at: ended, duration_seconds: (ended - start_at).to_i, updated_at: Time.current)
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

  def as_props(with_files: false)
    props = as_json(
      only: [ :id, :description, :start_at, :end_at, :duration_seconds, :billable ],
      include: {
        project: { only: [ :id, :name, :color ] },
        tags: { only: [ :id, :name ] }
      }
    ).merge(formattedDuration: formatted_duration)
    return props unless with_files

    props.merge(
      files: files.map { |file|
        {
          id: file.id,
          blob_id: file.blob_id,
          filename: file.filename.to_s,
          byte_size: file.byte_size,
          content_type: file.content_type
        }
      }
    )
  end

  def duration_hours
    (duration_seconds || 0) / SECONDS_PER_HOUR.to_f
  end

  def tag_names
    tags.pluck(:name)
  end

  # Starting a timer stops the user's other running timer in the workspace.
  def save_stopping_running_entries
    transaction do
      self.class.running.where(user_id: user_id, workspace_id: workspace_id).where.not(id: id).find_each(&:stop!) if running?
      save || raise(ActiveRecord::Rollback)
    end
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

  def end_after_start
    errors.add(:end_at, "must be after the start time") if end_at && start_at && end_at < start_at
  end

  def project_in_workspace
    return unless project

    # Compare ids when both are saved, and the records themselves when not.
    same = workspace_id && project.workspace_id ? project.workspace_id == workspace_id : project.workspace == workspace
    errors.add(:project, "must belong to this workspace") unless same
  end

  def one_running_entry
    others = self.class.running.where(user_id: user_id, workspace_id: workspace_id).where.not(id: id)
    errors.add(:base, "Another timer is already running") if others.exists?
  end

  def should_calculate_duration?
    end_at.present? && start_at.present? && (end_at_changed? || start_at_changed? || duration_seconds.nil?)
  end

  def calculate_duration_seconds
    self.duration_seconds = (end_at - start_at).to_i
  end
end
