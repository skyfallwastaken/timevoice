class WorkspacesController < ApplicationController
  def switch
    workspace_id = params[:workspace_id]
    workspace = current_user.workspaces.find(workspace_id)
    authorize workspace, :show?

    session[:workspace_id] = workspace.id
    redirect_back(fallback_location: root_path)
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: root_path, alert: "Workspace not found.")
  end
end
