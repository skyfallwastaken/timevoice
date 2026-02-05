class DashboardController < ApplicationController
  def index
    @running_entry = current_user.time_entries.running.includes(:project, :tags).first
    @recent_entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
      .includes(:project, :tags, files_attachments: :blob)
      .order(start_at: :desc)
      .limit(10)

    @projects = current_workspace.projects.includes(:client).order(:name)
    @tags = current_workspace.tags.order(:name)

    render inertia: "Dashboard/Index", props: {
      runningEntry: @running_entry&.as_json(
        only: [ :id, :description, :start_at, :billable ],
        include: {
          project: { only: [ :id, :name, :color ] },
          tags: { only: [ :id, :name ] }
        }
      ),
      recentEntries: @recent_entries.map { |entry|
        entry.as_json(
          only: [ :id, :description, :start_at, :end_at, :duration_seconds, :billable ],
          include: {
            project: { only: [ :id, :name, :color ] },
            tags: { only: [ :id, :name ] }
          }
        ).merge(
          formattedDuration: entry.formatted_duration,
          files: entry.files.map { |file| {
            id: file.id,
            blob_id: file.blob_id,
            filename: file.filename.to_s,
            byte_size: file.byte_size,
            content_type: file.content_type
          } }
        )
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

  def calendar
    week_start_date = begin
      params[:week_start].present? ? Date.parse(params[:week_start]) : Date.current.beginning_of_week
    rescue ArgumentError
      Date.current.beginning_of_week
    end

    week_end_date = week_start_date + 6.days

    @entries = current_user.time_entries
      .where(workspace: current_workspace)
      .in_date_range(week_start_date, week_end_date)
      .includes(:project, :tags)
      .order(start_at: :asc)

    @projects = current_workspace.projects.includes(:client).order(:name)
    @tags = current_workspace.tags.order(:name)

    render inertia: "Dashboard/Calendar", props: {
      entries: @entries.map { |entry|
        entry.as_json(
          only: [ :id, :description, :start_at, :end_at, :duration_seconds, :billable ],
          include: {
            project: { only: [ :id, :name, :color ] },
            tags: { only: [ :id, :name ] }
          }
        ).merge(formattedDuration: entry.formatted_duration)
      },
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
end
