class InvitesController < ApplicationController
  skip_before_action :require_workspace, only: [ :show, :accept, :decline ]
  before_action :set_invite, only: [ :show, :accept, :decline ]
  before_action :authorize_invite, only: [ :show, :accept, :decline ]

  def show
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
  private

  def set_invite
    @invite = Invite.find_by!(token: params[:token])
  end

  def authorize_invite
    authorize @invite, :show?
  end

  def workspace_root_path(workspace)
    "/#{workspace.hashid}"
  end
end
