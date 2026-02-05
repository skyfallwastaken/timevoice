module ReportCalculable
  extend ActiveSupport::Concern

  private

  def calculate_totals(entries)
    total_seconds = entries.sum { |e| e.duration_seconds || 0 }
    billable_seconds = entries.select(&:billable).sum { |e| e.duration_seconds || 0 }

    {
      total: total_seconds,
      billable: billable_seconds,
      non_billable: total_seconds - billable_seconds,
      daily: calculate_grouped_totals(entries) { |e| e.start_at.to_date },
      by_project: calculate_grouped_totals(entries) { |e| e.project&.name || "No Project" },
      by_client: calculate_grouped_totals(entries) { |e| e.project&.client&.name || "No Client" }
    }
  end

  def calculate_grouped_totals(entries, &grouper)
    entries.group_by(&grouper).transform_values do |grouped_entries|
      {
        total: grouped_entries.sum { |e| e.duration_seconds || 0 },
        billable: grouped_entries.select(&:billable).sum { |e| e.duration_seconds || 0 }
      }
    end
  end
end
