class OauthApplicationsController < ApplicationController
  before_action :set_oauth_application, only: [ :update, :destroy ]

  def index
    @applications = current_workspace.oauth_applications.order(created_at: :desc)

    render inertia: "Settings/Developer", props: {
      applications: @applications.map { |app| application_json(app) },
      scopes: OauthApplication.scope_descriptions
    }
  end

  def create
    @application = current_workspace.oauth_applications.build(oauth_application_params)
    @application.trust_level = "community"
    authorize @application

    if @application.save
      redirect_to settings_developer_path, flash: {
        notice: "Application created successfully!",
        new_secret: @application.plaintext_secret,
        secret_app_id: @application.id
      }
    else
      redirect_to settings_developer_path, alert: @application.errors.full_messages.join(", ")
    end
  end

  def update
    authorize @application

    if @application.update(oauth_application_params)
      redirect_to settings_developer_path, notice: "Application updated successfully!"
    else
      redirect_to settings_developer_path, alert: @application.errors.full_messages.join(", ")
    end
  end

  def destroy
    authorize @application
    @application.destroy

    redirect_to settings_developer_path, notice: "Application deleted successfully!"
  end

  def regenerate_secret
    @application = current_workspace.oauth_applications.find(params[:id])
    authorize @application, :update?

    @application.renew_secret
    @application.save!

    redirect_to settings_developer_path, flash: {
      notice: "Client secret regenerated. Make sure to copy your new secret!",
      new_secret: @application.plaintext_secret,
      secret_app_id: @application.id
    }
  end

  private

  def set_oauth_application
    @application = current_workspace.oauth_applications.find(params[:id])
  end

  def oauth_application_params
    params.require(:oauth_application).permit(:name, :redirect_uri, :confidential, scopes: [])
  end

  def application_json(app)
    {
      id: app.id,
      name: app.name,
      uid: app.uid,
      secret: app.secret,
      redirect_uri: app.redirect_uri,
      scopes: app.scopes_array,
      trust_level: app.trust_level,
      confidential: app.confidential,
      created_at: app.created_at.iso8601
    }
  end
end
