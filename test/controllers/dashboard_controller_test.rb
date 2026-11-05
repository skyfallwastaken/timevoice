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

    get "/#{@workspace.hashid}/calendar"
    assert_nil inertia_props["runningEntry"]

    get "/#{other.hashid}/calendar"
    assert_equal "Elsewhere", inertia_props.dig("runningEntry", "description")
  end
end
