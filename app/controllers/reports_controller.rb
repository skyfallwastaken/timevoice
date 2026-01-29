class ReportsController < ApplicationController
  def index
    start_date = parse_date(params[:start_date]) || Time.current.beginning_of_week.to_date
    end_date = parse_date(params[:end_date]) || Time.current.end_of_week.to_date

    @entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
      .where(start_at: start_date.beginning_of_day..end_date.end_of_day)
      .includes(:project, :tags)

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

  def calculate_totals(entries)
    total_seconds = entries.sum(&:duration_seconds)
    billable_seconds = entries.where(billable: true).sum(&:duration_seconds)
    non_billable_seconds = total_seconds - billable_seconds

    daily = entries.group_by { |e| e.start_at.to_date }.transform_values do |day_entries|
      {
        total: day_entries.sum(&:duration_seconds),
        billable: day_entries.select(&:billable).sum(&:duration_seconds)
      }
    end

    by_project = entries.group_by { |e| e.project&.name || "No Project" }.transform_values do |project_entries|
      {
        total: project_entries.sum(&:duration_seconds),
        billable: project_entries.select(&:billable).sum(&:duration_seconds)
      }
    end

    by_client = entries.group_by { |e| e.project&.client&.name || "No Client" }.transform_values do |client_entries|
      {
        total: client_entries.sum(&:duration_seconds),
        billable: client_entries.select(&:billable).sum(&:duration_seconds)
      }
    end

    {
      total: total_seconds,
      billable: billable_seconds,
      non_billable: non_billable_seconds,
      daily: daily,
      by_project: by_project,
      by_client: by_client
    }
  end
end
