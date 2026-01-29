class DashboardController < ApplicationController
  def index
    @running_entry = current_user.time_entries.running.first
    @recent_entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
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
        ).merge(formattedDuration: entry.formatted_duration)
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
    @entries = current_user.time_entries
      .where(workspace: current_workspace)
      .where(start_at: Time.current.beginning_of_week..Time.current.end_of_week)
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
        start: Time.current.beginning_of_week.to_date.to_s,
        end: Time.current.end_of_week.to_date.to_s
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
