require "test_helper"

class TimeEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in_as @user
  end

  test "starting a timer stops the one already running" do
    running = TimeEntry.create!(user: @user, workspace: @workspace, description: "Old", start_at: 1.hour.ago)

    post "/#{@workspace.hashid}/time_entries", params: { time_entry: { description: "New", start_at: Time.current.iso8601 } }

    assert running.reload.completed?
    assert_equal [ "New" ], @user.time_entries.where(workspace: @workspace).running.pluck(:description)
  end

  test "stopping at a requested end time never records time past now" do
    freeze_time
    entry = TimeEntry.create!(user: @user, workspace: @workspace, description: "Focus", start_at: 30.minutes.ago)
    patch "/#{@workspace.hashid}/time_entries/#{entry.id}/stop", params: { time_entry: { end_at: 5.minutes.ago.iso8601 } }
    assert_equal 25 * 60, entry.reload.duration_seconds

    later = TimeEntry.create!(user: @user, workspace: @workspace, description: "Late", start_at: 10.minutes.ago)
    patch "/#{@workspace.hashid}/time_entries/#{later.id}/stop", params: { time_entry: { end_at: 1.hour.from_now.iso8601 } }
    assert_equal 10 * 60, later.reload.duration_seconds
  end

  test "bulk update changes only the selected entries of the current user and adds tags" do
    tagged = time_entries(:one)
    extra_tag = Tag.create!(workspace: @workspace, name: "Extra")
    untouched = TimeEntry.create!(user: @user, workspace: @workspace, description: "Skip", start_at: 2.hours.ago, end_at: 1.hour.ago, billable: false)

    patch "/#{@workspace.hashid}/time_entries/bulk_update", params: {
      ids: [ tagged.id, time_entries(:two).id ],
      changes: { project_id: "", billable: true, add_tag_ids: [ extra_tag.id ] }
    }, as: :json

    tagged.reload
    assert_nil tagged.project
    assert tagged.billable
    assert_equal [ "Extra", "MyString" ], tagged.tags.pluck(:name).sort
    assert_not untouched.reload.billable
    assert_equal projects(:two), time_entries(:two).reload.project
  end

  test "bulk destroy deletes only the selected entries of the current user" do
    keep = TimeEntry.create!(user: @user, workspace: @workspace, description: "Keep", start_at: 2.hours.ago, end_at: 1.hour.ago)

    delete "/#{@workspace.hashid}/time_entries/bulk_destroy", params: { ids: [ time_entries(:one).id, time_entries(:two).id ] }, as: :json

    assert_not TimeEntry.exists?(time_entries(:one).id)
    assert TimeEntry.exists?(time_entries(:two).id)
    assert TimeEntry.exists?(keep.id)
  end
end
