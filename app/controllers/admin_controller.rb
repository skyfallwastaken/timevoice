class AdminController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :require_workspace

  before_action :authenticate_admin!

  private

  def authenticate_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end
end
