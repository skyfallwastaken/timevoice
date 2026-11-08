class MarketingController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :require_workspace

  def home
    if current_user
      target_workspace = current_user.default_workspace
      if target_workspace
        redirect_to workspace_timer_path(target_workspace)
        return
      end
    end

    render inertia: "Marketing/Home"
  end
end
