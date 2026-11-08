class DashboardController < ApplicationController
  ENTRY_RANGES = %w[today this_week last_week this_month all].freeze
  ENTRY_LIMIT = 200
  RECENT_DESCRIPTION_LIMIT = 50
  VIEWS = %w[list calendar].freeze

  def index
    authorize current_workspace, :show?

    view = params[:view].presence_in(VIEWS) || cookies[:timer_view].presence_in(VIEWS) || "list"
    cookies.permanent[:timer_view] = view if params[:view]

    render inertia: "Dashboard/Index", props: {
      view: view,
      projects: current_workspace.projects.includes(:client).order(:name).map { |project|
        project.as_json(
          only: [ :id, :name, :color, :billable_default ],
          include: { client: { only: [ :id, :name ] } }
        )
      },
      tags: current_workspace.tags.order(:name).as_json(only: [ :id, :name ]),
      recentDescriptions: recent_descriptions
    }.merge(view == "calendar" ? calendar_props : list_props)
  end

  private

  def list_props
    range = params[:range].presence_in(ENTRY_RANGES) || "this_week"
    period = range_bounds(range, list_anchor(range))
    filters = {
      range: range,
      date: period&.begin&.to_date&.to_s,
      project_id: params[:project_id].presence,
      q: params[:q].to_s.strip.presence
    }

    entries = workspace_entries
      .completed
      .includes(:project, :tags, files_attachments: :blob)
      .order(start_at: :desc)
      .limit(ENTRY_LIMIT)
    entries = entries.where(start_at: period) if period
    entries = entries.where(project_id: filters[:project_id]) if filters[:project_id]
    entries = entries.where(TimeEntry.arel_table[:description].matches("%#{TimeEntry.sanitize_sql_like(filters[:q])}%")) if filters[:q]

    {
      recentEntries: entries.map { |entry| entry_json(entry) },
      filters: filters,
      hasEntries: workspace_entries.completed.exists?,
      entryLimit: ENTRY_LIMIT
    }
  end

  def calendar_props
    week_start = begin
      params[:week_start].present? ? Date.parse(params[:week_start].to_s).beginning_of_week : Date.current.beginning_of_week
    rescue ArgumentError
      Date.current.beginning_of_week
    end

    entries = workspace_entries
      .completed
      .in_date_range(week_start, week_start + 6.days)
      .includes(:project, :tags, files_attachments: :blob)
      .order(start_at: :asc)

    {
      entries: entries.map { |entry| entry_json(entry) },
      weekStart: week_start.to_s
    }
  end

  def workspace_entries
    current_user.time_entries.where(workspace: current_workspace)
  end

  # The list's arrows send a day in the period to show.
  def list_anchor(range)
    Date.parse(params[:date].to_s).in_time_zone
  rescue ArgumentError
    range == "last_week" ? 1.week.ago : Time.current
  end

  def range_bounds(range, anchor)
    case range
    when "today" then anchor.all_day
    when "this_week", "last_week" then anchor.all_week
    when "this_month" then anchor.all_month
    end
  end

  # The latest entry for each distinct description, newest first, in one query.
  def recent_descriptions
    ranked = workspace_entries.completed.where.not(description: [ nil, "" ]).select(
      :id, :start_at,
      "ROW_NUMBER() OVER (PARTITION BY LOWER(time_entries.description) ORDER BY time_entries.start_at DESC, time_entries.id DESC) AS position"
    )
    latest_ids = TimeEntry.from(ranked, :time_entries).where(position: 1)
      .order(start_at: :desc).limit(RECENT_DESCRIPTION_LIMIT).select(:id)

    TimeEntry.where(id: latest_ids).eager_load(:tags).order(start_at: :desc).map { |entry|
      { description: entry.description, project_id: entry.project_id, tag_ids: entry.tags.map(&:id), billable: entry.billable }
    }
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
end
