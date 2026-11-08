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

  test "every page shares only the current user's running timer in the current workspace" do
    other = Workspace.create!(name: "Other", owner: @user)
    Membership.create!(workspace: other, user: @user, role: "owner")
    Membership.create!(workspace: @workspace, user: users(:two), role: "member")
    TimeEntry.create!(user: @user, workspace: other, description: "Elsewhere", start_at: 5.minutes.ago)
    TimeEntry.create!(user: users(:two), workspace: @workspace, description: "Someone else's", start_at: 5.minutes.ago)

    get "/#{@workspace.hashid}/clients"
    assert_nil inertia_props["runningEntry"]

    TimeEntry.create!(user: @user, workspace: @workspace, project: projects(:one), description: "Mine", start_at: 5.minutes.ago)

    get "/#{@workspace.hashid}/clients"
    running = inertia_props["runningEntry"]
    assert_equal "Mine", running["description"]
    assert_equal projects(:one).color, running.dig("project", "color")
  end

  test "recent descriptions list each description once with its latest entry's details" do
    tag = tags(:one)
    TimeEntry.create!(user: @user, workspace: @workspace, description: "Design review", billable: false,
      start_at: 3.days.ago, end_at: 3.days.ago + 1.hour)
    TimeEntry.create!(user: @user, workspace: @workspace, description: "design review", project: projects(:one), billable: true,
      start_at: 2.days.ago, end_at: 2.days.ago + 1.hour).tags << tag
    TimeEntry.create!(user: @user, workspace: @workspace, description: "Standup", start_at: 1.day.ago, end_at: 1.day.ago + 1.hour)
    TimeEntry.create!(user: @user, workspace: @workspace, description: "Still running", start_at: 1.hour.ago)
    TimeEntry.create!(user: users(:two), workspace: @workspace, description: "Not mine", start_at: 1.hour.ago, end_at: 30.minutes.ago)

    get "/#{@workspace.hashid}/timer"
    recent = inertia_props["recentDescriptions"]

    assert_equal [ "Standup", "design review", "MyText" ], recent.pluck("description")
    assert_equal({ "description" => "design review", "project_id" => projects(:one).id, "tag_ids" => [ tag.id ], "billable" => true }, recent.second)
  end

  test "the list's arrows show the period starting on the requested date" do
    TimeEntry.create!(user: @user, workspace: @workspace, description: "Week 44", start_at: Time.utc(2026, 10, 28, 10), end_at: Time.utc(2026, 10, 28, 11))
    TimeEntry.create!(user: @user, workspace: @workspace, description: "Week 45", start_at: Time.utc(2026, 11, 4, 10), end_at: Time.utc(2026, 11, 4, 11))

    travel_to Time.utc(2026, 11, 8, 12) do
      get "/#{@workspace.hashid}/timer", params: { view: "list", range: "this_week", date: "2026-10-26" }
      assert_equal [ "Week 44" ], inertia_props["recentEntries"].pluck("description")
      assert_equal "2026-10-26", inertia_props.dig("filters", "date")

      get "/#{@workspace.hashid}/timer", params: { view: "list", range: "this_month", date: "2026-10-01" }
      assert_equal [ "Week 44" ], inertia_props["recentEntries"].pluck("description")

      get "/#{@workspace.hashid}/timer", params: { view: "list" }
      assert_equal [ "Week 45" ], inertia_props["recentEntries"].pluck("description")
      assert_equal "2026-11-02", inertia_props.dig("filters", "date")
    end
  end

  test "entries list their own tags" do
    design = @workspace.tags.create!(name: "design")
    review = @workspace.tags.create!(name: "review")
    tagged = TimeEntry.create!(user: @user, workspace: @workspace, description: "Tagged", start_at: Time.utc(2026, 11, 4, 10), end_at: Time.utc(2026, 11, 4, 11))
    tagged.tags = [ review, design ]
    TimeEntry.create!(user: @user, workspace: @workspace, description: "Untagged", start_at: Time.utc(2026, 11, 4, 12), end_at: Time.utc(2026, 11, 4, 13))

    get "/#{@workspace.hashid}/timer", params: { range: "all" }
    tags = inertia_props["recentEntries"].to_h { |entry| [ entry["description"], entry["tags"] ] }
    assert_equal [ { "id" => review.id, "name" => "review" }, { "id" => design.id, "name" => "design" } ], tags["Tagged"]
    assert_equal [], tags["Untagged"]

    get "/#{@workspace.hashid}/timer", params: { view: "calendar", week_start: "2026-11-02" }
    assert_equal [ [ "review", "design" ], [] ], inertia_props["entries"].map { |entry| entry["tags"].pluck("name") }
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
