class ReportsController < ApplicationController
  include ReportCalculable

  def index
    start_date = parse_date(params[:start_date]) || Time.current.beginning_of_week.to_date
    end_date = parse_date(params[:end_date]) || Time.current.end_of_week.to_date

    @entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
      .in_date_range(start_date, end_date)
      .includes(:tags, project: :client)

    @totals = calculate_totals(@entries)

    render inertia: "Reports/Index", props: {
      entries: @entries.map { |entry|
        entry.as_json(
          only: [ :id, :description, :start_at, :end_at, :duration_seconds, :billable ],
          include: {
            project: { only: [ :id, :name, :color ] },
            tags: { only: [ :id, :name ] }
          }
        ).merge(formattedDuration: entry.formatted_duration)
      },
      totals: @totals,
      dateRange: {
        start: start_date.to_s,
        end: end_date.to_s
      },
      projects: current_workspace.projects.includes(:client).order(:name).map { |p|
        p.as_json(only: [ :id, :name, :color ], include: { client: { only: [ :id, :name ] } })
      }
    }
  end

  private

  def parse_date(date_string)
    return nil if date_string.blank?
    return nil unless date_string.match?(/^\d{4}-\d{2}-\d{2}$/)

    Date.parse(date_string)
  rescue ArgumentError
    nil
  end
end
