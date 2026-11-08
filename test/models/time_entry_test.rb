require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
  end

  test "a timer without a description, or one that starts in the future, can be stopped" do
    entry = TimeEntry.create!(user: @user, workspace: @workspace, start_at: 1.hour.from_now)

    entry.stop!

    assert_equal 0, entry.reload.duration_seconds
  end

  test "an entry cannot end before it starts" do
    entry = time_entries(:one)

    assert_not entry.update(end_at: entry.start_at - 1.hour)
    assert_includes entry.errors[:end_at], "must be after the start time"
  end

  test "an entry cannot use another workspace's project" do
    entry = TimeEntry.new(user: @user, workspace: @workspace, start_at: 1.hour.ago, end_at: Time.current, description: "x", project: projects(:two))

    assert_not entry.save
    assert_includes entry.errors[:project], "must belong to this workspace"
  end

  test "starting a timer stops the running one, and a stopped entry can't be reopened beside it" do
    running = TimeEntry.create!(user: @user, workspace: @workspace, start_at: 1.hour.ago, description: "First")
    started = TimeEntry.new(user: @user, workspace: @workspace, start_at: Time.current)

    assert started.save_stopping_running_entries
    assert_not_nil running.reload.end_at

    assert_not running.update(end_at: nil)
    assert_equal [ started ], TimeEntry.running.where(user: @user).to_a
  end
end
