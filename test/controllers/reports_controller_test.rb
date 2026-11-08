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

    get "/#{@workspace.hashid}/reports", params: { start_date: "2026-10-01", end_date: "2026-12-31" }

    totals = inertia_props["totals"]
    assert_equal "week", totals["bucket"]
    assert_equal "2026-10-01", totals["daily"].keys.first
    assert_equal "2026-12-28", totals["daily"].keys.last
    assert_equal 14, totals["daily"].size
    assert_equal 3600, totals["daily"]["2026-11-02"]["total"]
  end
end
