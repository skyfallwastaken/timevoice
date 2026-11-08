class ReportsController < ApplicationController
  include ReportCalculable

  MAX_RANGE = 5.years

  def index
    authorize current_workspace, :show?

    start_date = parse_date(params[:start_date]) || Time.current.beginning_of_week.to_date
    end_date = parse_date(params[:end_date]) || Time.current.end_of_week.to_date
    earliest_start = end_date - MAX_RANGE + 1.day
    if start_date < earliest_start
      start_date = earliest_start
      flash.now[:notice] = "Reports cover at most 5 years, so this one starts on #{start_date.strftime("%b %-d, %Y")}."
    end

    @entries = policy_scope(TimeEntry)
      .completed
      .in_date_range(start_date, end_date)
      .includes(project: :client)
      .order(start_at: :asc)
    @entries = @entries.where(project_id: params[:project_id]) if params[:project_id].present?

    @totals = calculate_totals(@entries, start_date..end_date)
    tags = TimeEntry.tags_json_by_entry_id(@entries)

    render inertia: "Reports/Index", props: {
      entries: @entries.map { |entry| entry.as_props(tags: tags.fetch(entry.id, [])) },
      totals: @totals,
      dateRange: {
        start: start_date.to_s,
        end: end_date.to_s
      },
      projectId: params[:project_id].presence,
      projects: current_workspace.projects.includes(:client).order(:name).map(&:as_props)
    }
  end

  private

  def parse_date(date_string)
    date_string = date_string.to_s
    return nil if date_string.blank?
    return nil unless date_string.match?(/^\d{4}-\d{2}-\d{2}$/)

    Date.parse(date_string)
  rescue ArgumentError
    nil
  end
end
