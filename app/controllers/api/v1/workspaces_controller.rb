# frozen_string_literal: true

module Api
  module V1
    class WorkspacesController < BaseController
      def index
        workspaces = current_user.workspaces.order(:name)

        render json: workspaces.as_json(only: [ :id, :name ])
      end

      def show
        workspace = current_user.workspaces.find(params[:id])

        render json: workspace.as_json(only: [ :id, :name ])
      end
    end
  end
end
