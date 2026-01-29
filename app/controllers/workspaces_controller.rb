class WorkspacesController < ApplicationController
  def create
    authorize Workspace, :create?

    workspace = current_user.workspaces.new(workspace_params)
    workspace.owner = current_user

    if workspace.save

      workspace.memberships.create!(user: current_user, role: :owner)

      session[:workspace_id] = workspace.id
      redirect_back(fallback_location: root_path, notice: "Workspace created successfully.")
    else
      redirect_back(fallback_location: root_path, alert: workspace.errors.full_messages.join(", "))
    end
  end

  def switch
    workspace_hashid = params[:workspace_id]
    workspace_id = Workspace.decode_id(workspace_hashid)
    workspace = current_user.workspaces.find(workspace_id)
    authorize workspace, :show?

    session[:workspace_id] = workspace.id
    redirect_to "/#{workspace.hashid}/timer"
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: root_path, alert: "Workspace not found.")
  end

  private

  def workspace_params
    params.require(:workspace).permit(:name)
  end
end
