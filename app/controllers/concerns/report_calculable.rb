module ReportCalculable
  extend ActiveSupport::Concern

  DAILY_BUCKET_MAX_DAYS = 62
  WEEKLY_BUCKET_MAX_DAYS = 371
  BUCKET_STEPS = { "day" => 1.day, "week" => 1.week, "month" => 1.month }.freeze

  private

  def calculate_totals(entries, date_range)
    total_seconds = entries.sum { |e| e.duration_seconds || 0 }
    billable_seconds = entries.select(&:billable).sum { |e| e.duration_seconds || 0 }
    bucket = timeline_bucket(date_range)

    {
      total: total_seconds,
      billable: billable_seconds,
      non_billable: total_seconds - billable_seconds,
      bucket: bucket,
      daily: calculate_timeline(entries, date_range, bucket),
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

  # Every bucket in the range, including empty ones, so the chart shows gaps.
  # Long ranges are bucketed by week (then month) to keep the bar count small.
  def timeline_bucket(date_range)
    days = (date_range.end - date_range.begin).to_i + 1
    if days <= DAILY_BUCKET_MAX_DAYS then "day"
    elsif days <= WEEKLY_BUCKET_MAX_DAYS then "week"
    else "month"
    end
  end

  def calculate_timeline(entries, date_range, bucket)
    totals = calculate_grouped_totals(entries) do |e|
      [ timeline_bucket_start(e.start_at.to_date, bucket), date_range.begin ].max
    end

    keys = []
    date = date_range.begin
    while date <= date_range.end
      keys << date
      date = timeline_bucket_start(date, bucket) + BUCKET_STEPS.fetch(bucket)
    end

    keys.index_with { |key| totals.fetch(key, { total: 0, billable: 0 }) }
  end

  def timeline_bucket_start(date, bucket)
    case bucket
    when "week" then date.beginning_of_week
    when "month" then date.beginning_of_month
    else date
    end
  end
end
