require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in_as @user
  end

  test "daily totals include days without entries across the requested range" do
    TimeEntry.create!(
      user: @user, workspace: @workspace, description: "Design", billable: true,
      start_at: Time.utc(2026, 11, 4, 9), end_at: Time.utc(2026, 11, 4, 11)
    )

    get "/#{@workspace.hashid}/reports", params: { start_date: "2026-11-02", end_date: "2026-11-08" }

    totals = inertia_props["totals"]
    assert_equal "day", totals["bucket"]
    assert_equal ("2026-11-02".."2026-11-08").to_a, totals["daily"].keys
    assert_equal({ "total" => 0, "billable" => 0 }, totals["daily"]["2026-11-02"])
    assert_equal({ "total" => 7200, "billable" => 7200 }, totals["daily"]["2026-11-04"])
  end

  test "long ranges are bucketed by week, starting at the range start" do
    TimeEntry.create!(
      user: @user, workspace: @workspace, description: "Review",
      start_at: Time.utc(2026, 11, 4, 9), end_at: Time.utc(2026, 11, 4, 10)
    )
    TimeEntry.create!(
      user: @user, workspace: @workspace, description: "Kickoff",
      start_at: Time.utc(2026, 10, 3, 9), end_at: Time.utc(2026, 10, 3, 9, 30)
    )

    get "/#{@workspace.hashid}/reports", params: { start_date: "2026-10-01", end_date: "2026-12-31" }

    totals = inertia_props["totals"]
    assert_equal "week", totals["bucket"]
    assert_equal "2026-10-01", totals["daily"].keys.first
    assert_equal "2026-12-28", totals["daily"].keys.last
    assert_equal 14, totals["daily"].size
    assert_equal 1800, totals["daily"]["2026-10-01"]["total"]
    assert_equal 0, totals["daily"]["2026-10-05"]["total"]
    assert_equal 3600, totals["daily"]["2026-11-02"]["total"]
  end

  test "ranges over 5 years are clamped and bucketed by month" do
    TimeEntry.create!(
      user: @user, workspace: @workspace, description: "Old work",
      start_at: Time.utc(2021, 11, 20, 9), end_at: Time.utc(2021, 11, 20, 10)
    )

    get "/#{@workspace.hashid}/reports", params: { start_date: "1900-01-15", end_date: "2026-11-08" }

    assert_equal "2021-11-09", inertia_props.dig("dateRange", "start")
    assert_match "at most 5 years", inertia_props.dig("flash", "notice")
    totals = inertia_props["totals"]
    assert_equal "month", totals["bucket"]
    assert_equal 61, totals["daily"].size
    assert_equal "2021-11-09", totals["daily"].keys.first
    assert_equal "2026-11-01", totals["daily"].keys.last
    assert_equal 3600, totals["daily"]["2021-11-09"]["total"]
    assert_equal 0, totals["daily"]["2021-12-01"]["total"]
  end

  test "projects include billable_default" do
    projects(:one).update_column(:billable_default, true)

    get "/#{@workspace.hashid}/reports"

    assert_equal [ true ], inertia_props["projects"].pluck("billable_default")
  end
end
