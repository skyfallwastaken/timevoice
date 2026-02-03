class MarketingController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :require_workspace

  def home
    if current_user
      target_workspace = current_user.last_used_workspace || current_user.workspaces.first
      if target_workspace
        redirect_to "/#{target_workspace.hashid}/timer"
        return
      end
    end

    render inertia: "Marketing/Home"
  end
end
