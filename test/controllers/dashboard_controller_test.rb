require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in_as @user
  end

  test "today is bucketed in the browser's timezone" do
    TimeEntry.create!(
      user: @user, workspace: @workspace, description: "Late night",
      start_at: Time.utc(2026, 3, 2, 23, 30), end_at: Time.utc(2026, 3, 2, 23, 45)
    )

    travel_to Time.utc(2026, 3, 3, 10, 0) do
      cookies[:tz] = "Asia/Tokyo"
      get "/#{@workspace.hashid}/timer", params: { range: "today" }
      assert_includes inertia_props["recentEntries"].pluck("description"), "Late night"

      cookies[:tz] = "UTC"
      get "/#{@workspace.hashid}/timer", params: { range: "today" }
      assert_not_includes inertia_props["recentEntries"].pluck("description"), "Late night"
    end
  end

  test "a timer running in another workspace is not shown" do
    other = Workspace.create!(name: "Other", owner: @user)
    Membership.create!(workspace: other, user: @user, role: "owner")
    TimeEntry.create!(user: @user, workspace: other, description: "Elsewhere", start_at: 5.minutes.ago)

    get "/#{@workspace.hashid}/timer"
    assert_nil inertia_props["runningEntry"]

    get "/#{@workspace.hashid}/timer", params: { view: "calendar" }
    assert_nil inertia_props["runningEntry"]

    get "/#{other.hashid}/timer", params: { view: "calendar" }
    assert_equal "Elsewhere", inertia_props.dig("runningEntry", "description")
  end

  test "the calendar view is remembered and shows the requested week" do
    TimeEntry.create!(
      user: @user, workspace: @workspace, description: "Week 45",
      start_at: Time.utc(2026, 11, 4, 10), end_at: Time.utc(2026, 11, 4, 11)
    )

    get "/#{@workspace.hashid}/calendar", params: { week_start: "2026-11-05" }
    assert_redirected_to "/#{@workspace.hashid}/timer?view=calendar&week_start=2026-11-05"

    get "/#{@workspace.hashid}/timer", params: { view: "calendar", week_start: "2026-11-05" }
    assert_equal "2026-11-02", inertia_props["weekStart"]
    assert_equal [ "Week 45" ], inertia_props["entries"].pluck("description")

    get "/#{@workspace.hashid}/timer"
    assert_equal "calendar", inertia_props["view"]

    get "/#{@workspace.hashid}/timer", params: { view: "list" }
    get "/#{@workspace.hashid}/timer"
    assert_equal "list", inertia_props["view"]
  end

  test "the Amp widget script loads only for admins" do
    widget = "script[src='https://ampcode.com/w/client_01M6R2YREB0ZEYGG2BFBYVZAAY.js']"

    get "/#{@workspace.hashid}/timer"
    assert_select widget, count: 0

    @user.update!(admin: true)
    get "/#{@workspace.hashid}/timer"
    assert_select widget, count: 1
  end
end
