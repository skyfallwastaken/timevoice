# frozen_string_literal: true

module Api
  module V1
    class ProjectsController < BaseController
      before_action :require_workspace!
      before_action :set_project, only: [ :show, :update, :destroy ]

      def index
        projects = current_workspace.projects.includes(:client).order(:name)

        render json: projects.map { |project| serialize_project(project) }
      end

      def show
        render json: serialize_project(@project)
      end

      def create
        require_scope!(:projects)
        return if performed?

        project = current_workspace.projects.build(project_attrs)

        if project.save
          render json: serialize_project(project), status: :created
        else
          render json: { error: "unprocessable_entity", message: project.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:projects)
        return if performed?

        if @project.update(project_attrs)
          render json: serialize_project(@project)
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
        project_id = Project.decode_id(params[:id])
        @project = current_workspace.projects.find_by!(id: project_id)
      end

      def project_attrs
        src = api_params(:project, :name, :client_id, :color, :billable_default)
        attrs = {}
        attrs[:name] = src[:name] if src.key?(:name)
        attrs[:color] = src[:color] if src.key?(:color)
        attrs[:billable_default] = src[:billable_default] if src.key?(:billable_default)
        if src.key?(:client_id)
          attrs[:client_id] = src[:client_id].present? ? current_workspace.clients.find_by!(id: Client.decode_id(src[:client_id].to_s)).id : nil
        end
        attrs
      end

      def serialize_project(project)
        {
          id: Project.encode_id(project.id),
          name: project.name,
          color: project.color,
          billable_default: project.billable_default,
          client: project.client && { id: Client.encode_id(project.client.id), name: project.client.name }
        }
      end
    end
  end
end
