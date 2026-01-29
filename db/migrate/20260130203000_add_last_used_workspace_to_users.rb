class AddLastUsedWorkspaceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :last_used_workspace, foreign_key: { to_table: :workspaces }
  end
end
