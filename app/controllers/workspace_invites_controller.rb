class WorkspaceInvitesController < ApplicationController
  def destroy
    invite = current_workspace.invites.find(params[:id])
    authorize invite

    invite.destroy
    redirect_to settings_workspace_path, notice: "Invitation to #{invite.email} cancelled."
  end
end
