# frozen_string_literal: true

module Api
  module V1
    class WorkspacesController < BaseController
      def index
        workspaces = current_user.workspaces.order(:name)

        render json: workspaces.map { |workspace| serialize_workspace(workspace) }
      end

      def show
        workspace_id = Workspace.decode_id(params[:id])
        workspace = current_user.workspaces.find_by!(id: workspace_id)

        render json: serialize_workspace(workspace)
      end

      private

      def serialize_workspace(workspace)
        { id: workspace.hashid, name: workspace.name, created_at: workspace.created_at.iso8601(3) }
      end
    end
  end
end
