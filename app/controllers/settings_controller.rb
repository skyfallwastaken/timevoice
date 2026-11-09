class SettingsController < ApplicationController
  before_action :authorize_workspace_view, only: [ :workspace, :billing, :themes ]

  def workspace
    @workspace = current_workspace
    @members = current_workspace.memberships
      .includes(:user)
      .order(created_at: :desc)
    @pending_invites = current_workspace.invites.pending.includes(:inviter).order(created_at: :desc)

    render inertia: "Settings/Workspace", props: {
      workspace: @workspace.as_json(only: [ :id, :name, :created_at ]),
      members: @members.map { |membership|
        membership.as_json(
          only: [ :id, :role, :created_at ],
          include: { user: { only: [ :id, :name, :email, :avatar_url ] } }
        )
      },
      pendingInvites: @pending_invites.map { |invite|
        {
          id: invite.id,
          email: invite.email,
          role: invite.role,
          inviter_name: invite.inviter.name,
          invitee_avatar: User.gravatar_url(invite.email),
          expires_at: invite.expires_at.iso8601,
          created_at: invite.created_at.iso8601
        }
      },
      canInvite: current_workspace.admin?(current_user)
    }
  end

  def update_workspace
    @workspace = current_workspace
    authorize @workspace, :update?

    if @workspace.update(workspace_params)
      redirect_to settings_workspace_path, notice: "Workspace updated successfully!"
    else
      redirect_with_record_errors settings_workspace_path, @workspace
    end
  end

  def destroy_workspace
    @workspace = current_workspace
    authorize @workspace, :destroy?

    if params[:confirm_name] != @workspace.name
      redirect_to settings_workspace_path, alert: "Type the workspace name to confirm deleting it."
      return
    end

    if current_user.workspaces.count <= 1
      redirect_to settings_workspace_path, alert: "You can't delete your only workspace."
      return
    end

    User.where(last_used_workspace_id: @workspace.id).update_all(last_used_workspace_id: nil)

    if @workspace.destroy
      session.delete(:workspace_id)
      redirect_to root_path, notice: "Workspace deleted successfully!"
    else
      redirect_to settings_workspace_path, alert: "Couldn't delete workspace. Please try again."
    end
  end

  def billing
    @invoice_settings = current_workspace.invoice_setting

    if @invoice_settings
      settings_json = @invoice_settings.as_json(only: [ :id, :sender_name, :sender_address, :billable_rate_cents, :notes ])
    else
      settings_json = {
        sender_name: current_user.name,
        sender_address: "",
        billable_rate_cents: 0,
        notes: ""
      }
    end

    render inertia: "Settings/Billing", props: {
      invoiceSettings: settings_json,
      canEdit: policy(current_workspace).update?,
      notesMaxLength: InvoiceSetting::NOTES_MAX_LENGTH
    }
  end

  def update_billing
    @invoice_settings = current_workspace.invoice_setting || current_workspace.build_invoice_setting
    authorize current_workspace, :update?

    if @invoice_settings.update(billing_params)
      redirect_to settings_billing_path, notice: "Billing settings updated successfully!"
    else
      redirect_with_record_errors settings_billing_path, @invoice_settings
    end
  end

  def themes
    render inertia: "Settings/Themes", props: {
      themes: Theme.all.map(&:to_h),
      currentTheme: current_theme.key
    }
  end

  def update_theme
    if current_user.update(theme: params[:theme])
      redirect_to settings_themes_path
    else
      redirect_to settings_themes_path, alert: "That theme isn't available."
    end
  end

  def update_clock
    current_user.update!(use_24_hour_clock: params[:use_24_hour_clock].to_s == "true")
    redirect_to settings_themes_path
  end

  private

  def authorize_workspace_view
    authorize current_workspace, :show?
  end

  def billing_params
    optional_params(:setting, :sender_name, :sender_address, :billable_rate_cents, :notes)
  end

  def workspace_params
    params.require(:workspace).permit(:name)
  end
end
