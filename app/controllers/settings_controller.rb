class SettingsController < ApplicationController
  def workspace
    @workspace = current_workspace
    @members = current_workspace.memberships
      .includes(:user)
      .order(created_at: :desc)

    render inertia: "Settings/Workspace", props: {
      workspace: @workspace.as_json(only: [ :id, :name, :created_at ]),
      members: @members.map { |membership|
        membership.as_json(
          only: [ :id, :role, :created_at ],
          include: { user: { only: [ :id, :name, :email, :avatar_url ] } }
        )
      }
    }
  end

  def billing
    @invoice_settings = current_workspace.invoice_setting

    if @invoice_settings
      settings_json = @invoice_settings.as_json(only: [ :id, :sender_name, :sender_address, :billable_rate_cents ])
    else
      settings_json = {
        sender_name: current_user.name,
        sender_address: "",
        billable_rate_cents: 0
      }
    end

    render inertia: "Settings/Billing", props: {
      invoiceSettings: settings_json
    }
  end

  def update_billing
    @invoice_settings = current_workspace.invoice_setting || current_workspace.build_invoice_setting

    if @invoice_settings.update(billing_params)
      redirect_to settings_billing_path, notice: "Billing settings updated successfully!"
    else
      redirect_to settings_billing_path, alert: @invoice_settings.errors.full_messages.join(", ")
    end
  end

  private

  def billing_params
    params.require(:invoice_setting).permit(:sender_name, :sender_address, :billable_rate_cents)
  end
end
