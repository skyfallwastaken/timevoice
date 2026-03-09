require "test_helper"

class WorkspacesControllerTest < ActiveSupport::TestCase
  test "create skips require_workspace" do
    callback = WorkspacesController._process_action_callbacks.find do |current|
      current.kind == :before && current.filter == :require_workspace
    end

    skip_actions = callback
      .instance_variable_get(:@unless)
      .filter_map { |condition| condition.instance_variable_get(:@actions)&.to_a }
      .flatten

    assert_includes skip_actions, "create"
  end
end
