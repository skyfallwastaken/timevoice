class InvitesController < ApplicationController
  skip_before_action :require_workspace, only: [ :show, :accept, :decline ]

  def show
    @invite = Invite.find_by!(token: params[:token])

    if @invite.expired?
      redirect_to root_path, alert: "This invitation has expired."
      return
    end

    if @invite.status != "pending"
      redirect_to root_path, alert: "This invitation is no longer valid."
      return
    end

    if current_user.nil?
      session[:pending_invite_token] = @invite.token
      redirect_to signin_path, notice: "Please sign in to accept the invitation."
      return
    end

    if @invite.workspace.member?(current_user)
      redirect_to workspace_root_path(@invite.workspace), notice: "You're already a member of this workspace."
      return
    end

    render inertia: "Invites/Show", props: {
      invite: {
        token: @invite.token,
        workspace_name: @invite.workspace.name,
        inviter_name: @invite.inviter.name,
        inviter_avatar: @invite.inviter.avatar_url,
        role: @invite.role,
        expires_at: @invite.expires_at.iso8601
      }
    }
  end

  def accept
    @invite = Invite.find_by!(token: params[:token])

    if @invite.expired?
      redirect_to root_path, alert: "This invitation has expired."
      return
    end

    unless @invite.pending?
      redirect_to root_path, alert: "This invitation is no longer valid."
      return
    end

    if current_user.nil?
      session[:pending_invite_token] = @invite.token
      redirect_to signin_path, notice: "Please sign in to accept the invitation."
      return
    end

    if @invite.workspace.member?(current_user)
      @invite.update!(status: "accepted")
      redirect_to workspace_root_path(@invite.workspace), notice: "You're already a member of this workspace."
      return
    end

    if @invite.accept!(current_user)
      current_user.update!(last_used_workspace: @invite.workspace)
      redirect_to workspace_root_path(@invite.workspace), notice: "Welcome to #{@invite.workspace.name}!"
    else
      redirect_to root_path, alert: "Could not accept invitation. Please try again."
    end
  end

  def decline
    @invite = Invite.find_by!(token: params[:token])

    unless @invite.pending?
      redirect_to root_path, alert: "This invitation is no longer valid."
      return
    end

    if current_user.nil?
      session[:pending_invite_token] = @invite.token
      redirect_to signin_path, notice: "Please sign in to decline the invitation."
      return
    end

    @invite.decline!
    redirect_to root_path, notice: "Invitation declined."
  end

  def index
    invites = current_user.pending_invites.includes(:workspace, :inviter).valid

    render inertia: "Invites/Index", props: {
      invites: invites.map { |invite|
        {
          token: invite.token,
          workspace_name: invite.workspace.name,
          inviter_name: invite.inviter.name,
          inviter_avatar: invite.inviter.avatar_url,
          role: invite.role,
          expires_at: invite.expires_at.iso8601
        }
      }
    }
  end

  private

  def workspace_root_path(workspace)
    "/#{workspace.hashid}"
  end
end
