class DashboardController < ApplicationController
  ENTRY_RANGES = %w[today this_week last_week this_month all].freeze
  ENTRY_LIMIT = 200

  def index
    authorize current_workspace, :show?

    filters = {
      range: params[:range].presence_in(ENTRY_RANGES) || "this_week",
      project_id: params[:project_id].presence,
      q: params[:q].to_s.strip.presence
    }

    entries = workspace_entries
      .completed
      .includes(:project, :tags, files_attachments: :blob)
      .order(start_at: :desc)
      .limit(ENTRY_LIMIT)
    entries = entries.where(start_at: range_bounds(filters[:range])) unless filters[:range] == "all"
    entries = entries.where(project_id: filters[:project_id]) if filters[:project_id]
    entries = entries.where(TimeEntry.arel_table[:description].matches("%#{TimeEntry.sanitize_sql_like(filters[:q])}%")) if filters[:q]

    @projects = current_workspace.projects.includes(:client).order(:name)
    @tags = current_workspace.tags.order(:name)

    render inertia: "Dashboard/Index", props: {
      runningEntry: running_entry_json,
      recentEntries: entries.map { |entry| entry_json(entry) },
      projects: @projects.map { |project|
        project.as_json(
          only: [ :id, :name, :color, :billable_default ],
          include: { client: { only: [ :id, :name ] } }
        )
      },
      tags: @tags.as_json(only: [ :id, :name ]),
      filters: filters,
      hasEntries: workspace_entries.completed.exists?,
      totals: {
        today: workspace_entries.completed.where(start_at: Time.current.all_day).sum(:duration_seconds),
        week: workspace_entries.completed.where(start_at: Time.current.all_week).sum(:duration_seconds)
      },
      entryLimit: ENTRY_LIMIT
    }
  end

  def calendar
    authorize current_workspace, :show?

    week_start_date = begin
      params[:week_start].present? ? Date.parse(params[:week_start]) : Date.current.beginning_of_week
    rescue ArgumentError
      Date.current.beginning_of_week
    end

    week_end_date = week_start_date + 6.days

    @entries = workspace_entries
      .in_date_range(week_start_date, week_end_date)
      .includes(:project, :tags, files_attachments: :blob)
      .order(start_at: :asc)

    @projects = current_workspace.projects.includes(:client).order(:name)
    @tags = current_workspace.tags.order(:name)

    render inertia: "Dashboard/Calendar", props: {
      runningEntry: running_entry_json,
      entries: @entries.map { |entry| entry_json(entry) },
      currentWeek: {
        start: week_start_date.to_s,
        end: week_end_date.to_s
      },
      projects: @projects.map { |project|
        project.as_json(
          only: [ :id, :name, :color, :billable_default ],
          include: { client: { only: [ :id, :name ] } }
        )
      },
      tags: @tags.as_json(only: [ :id, :name ])
    }
  end

  private

  def workspace_entries
    current_user.time_entries.where(workspace: current_workspace)
  end

  def range_bounds(range)
    case range
    when "today" then Time.current.all_day
    when "this_week" then Time.current.all_week
    when "last_week" then 1.week.ago.all_week
    when "this_month" then Time.current.all_month
    end
  end

  def entry_json(entry)
    entry.as_json(
      only: [ :id, :description, :start_at, :end_at, :duration_seconds, :billable ],
      include: {
        project: { only: [ :id, :name, :color ] },
        tags: { only: [ :id, :name ] }
      }
    ).merge(
      formattedDuration: entry.formatted_duration,
      files: entry.files.map { |file|
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

  def running_entry_json
    workspace_entries.running.includes(:project, :tags).first&.as_json(
      only: [ :id, :description, :start_at, :billable ],
      include: {
        project: { only: [ :id, :name, :color ] },
        tags: { only: [ :id, :name ] }
      }
    )
  end
end
