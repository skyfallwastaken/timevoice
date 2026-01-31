class MembershipsController < ApplicationController
  def create
    membership = current_workspace.memberships.new
    authorize membership

    email = membership_params[:email].to_s.strip.downcase
    if email.blank?
      redirect_to settings_workspace_path, alert: "Email is required."
      return
    end

    user = User.find_by("lower(email) = ?", email)
    if user.nil?
      redirect_to settings_workspace_path, alert: "No user found with that email. They need to sign in first."
      return
    end

    if current_workspace.member?(user)
      redirect_to settings_workspace_path, alert: "That user is already a member of this workspace."
      return
    end

    membership.user = user
    # Only owners can assign admin role; admins can only add members
    requested_role = params[:role].to_s.presence_in([ "member", "admin" ])
    membership.role = if current_workspace.owner?(current_user) && requested_role
      requested_role
    else
      "member"
    end

    if membership.save
      redirect_to settings_workspace_path, notice: "Invited #{user.name} to the workspace."
    else
      redirect_to settings_workspace_path, alert: membership.errors.full_messages.join(", ")
    end
  end

  def destroy
    membership = current_workspace.memberships.includes(:user).find(params[:id])
    authorize membership

    if membership.role == "owner"
      redirect_to settings_workspace_path, alert: "You can't remove the workspace owner."
      return
    end

    member_name = membership.user&.name || "Member"
    membership.destroy

    redirect_to settings_workspace_path, notice: "Removed #{member_name} from the workspace."
  end

  private

  def membership_params
    optional_params(:membership, :email)
  end
end
