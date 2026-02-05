# frozen_string_literal: true

module Api
  module V1
    class ProjectsController < BaseController
      before_action :set_project, only: [ :show, :update, :destroy ]

      def index
        projects = current_workspace.projects.includes(:client).order(:name)

        render json: projects.map { |project|
          project.as_json(
            only: [ :id, :name, :color, :billable_default ],
            include: { client: { only: [ :id, :name ] } }
          )
        }
      end

      def show
        render json: @project.as_json(
          only: [ :id, :name, :color, :billable_default ],
          include: { client: { only: [ :id, :name ] } }
        )
      end

      def create
        require_scope!(:projects)
        return if performed?

        project = current_workspace.projects.build(project_params)

        if project.save
          render json: project.as_json(
            only: [ :id, :name, :color, :billable_default ],
            include: { client: { only: [ :id, :name ] } }
          ), status: :created
        else
          render json: { error: "unprocessable_entity", message: project.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:projects)
        return if performed?

        if @project.update(project_params)
          render json: @project.as_json(
            only: [ :id, :name, :color, :billable_default ],
            include: { client: { only: [ :id, :name ] } }
          )
        else
          render json: { error: "unprocessable_entity", message: @project.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        require_scope!(:projects)
        return if performed?

        @project.destroy
        head :no_content
      end

      private

      def set_project
        @project = current_workspace.projects.find(params[:id])
      end

      def project_params
        params.require(:project).permit(:name, :client_id, :color, :billable_default)
      end
    end
  end
end
