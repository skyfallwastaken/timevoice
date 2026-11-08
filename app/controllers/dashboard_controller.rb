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
      projects: current_workspace.projects.includes(:client).order(:name).map(&:as_props),
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

    entries = policy_scope(TimeEntry)
      .completed
      .includes(:project, files_attachments: :blob)
      .order(start_at: :desc)
      .limit(ENTRY_LIMIT)
    entries = entries.where(start_at: period) if period
    entries = entries.where(project_id: filters[:project_id]) if filters[:project_id]
    entries = entries.where(TimeEntry.arel_table[:description].matches("%#{TimeEntry.sanitize_sql_like(filters[:q])}%")) if filters[:q]

    {
      recentEntries: entries_props(entries),
      filters: filters,
      hasEntries: policy_scope(TimeEntry).completed.exists?,
      entryLimit: ENTRY_LIMIT
    }
  end

  def calendar_props
    week_start = begin
      params[:week_start].present? ? Date.parse(params[:week_start].to_s).beginning_of_week : Date.current.beginning_of_week
    rescue ArgumentError
      Date.current.beginning_of_week
    end

    entries = policy_scope(TimeEntry)
      .completed
      .in_date_range(week_start, week_start + 6.days)
      .includes(:project, files_attachments: :blob)
      .order(start_at: :asc)

    {
      entries: entries_props(entries),
      weekStart: week_start.to_s
    }
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
    ranked = policy_scope(TimeEntry).completed.where.not(description: [ nil, "" ]).select(
      :id, :start_at,
      "ROW_NUMBER() OVER (PARTITION BY LOWER(time_entries.description) ORDER BY time_entries.start_at DESC, time_entries.id DESC) AS position"
    )
    latest_ids = TimeEntry.from(ranked, :time_entries).where(position: 1)
      .order(start_at: :desc).limit(RECENT_DESCRIPTION_LIMIT).select(:id)

    TimeEntry.where(id: latest_ids).eager_load(:tags).order(start_at: :desc).map { |entry|
      { description: entry.description, project_id: entry.project_id, tag_ids: entry.tags.map(&:id), billable: entry.billable }
    }
  end

  def entries_props(entries)
    tags = TimeEntry.tags_json_by_entry_id(entries)
    entries.map { |entry| entry.as_props(with_files: true, tags: tags.fetch(entry.id, [])) }
  end
end
