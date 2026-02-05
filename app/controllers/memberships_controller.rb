class MembershipsController < ApplicationController
  def create
    membership = current_workspace.memberships.new
    authorize membership

    email = membership_params[:email].to_s.strip.downcase
    if email.blank?
      redirect_to settings_workspace_path, alert: "Email is required."
      return
    end

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      redirect_to settings_workspace_path, alert: "Please enter a valid email address."
      return
    end

    user = User.find_by("lower(email) = ?", email)

    if user && current_workspace.member?(user)
      redirect_to settings_workspace_path, alert: "That user is already a member of this workspace."
      return
    end

    existing_invite = current_workspace.invites.pending.find_by("lower(email) = ?", email)
    if existing_invite
      redirect_to settings_workspace_path, alert: "An invitation has already been sent to this email."
      return
    end

    requested_role = params[:role].to_s.presence_in(%w[member admin]) || "member"
    role = if current_workspace.owner?(current_user)
      requested_role
    else
      "member"
    end

    invite = current_workspace.invites.build(
      email: email,
      role: role,
      inviter: current_user
    )

    if invite.save
      SendInviteEmailJob.perform_later(invite_id: invite.id)
      redirect_to settings_workspace_path, notice: "Invitation sent to #{email}."
    else
      redirect_to settings_workspace_path, alert: invite.errors.full_messages.join(", ")
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

    if membership.user == current_user
      redirect_to root_path, notice: "You have left the workspace."
    else
      redirect_to settings_workspace_path, notice: "Removed #{member_name} from the workspace."
    end
  end

  private

  def membership_params
    optional_params(:membership, :email)
  end
end
