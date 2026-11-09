# frozen_string_literal: true

module Api
  module V1
    class ProjectsController < BaseController
      before_action :require_workspace!
      before_action :set_project, only: [ :show, :update, :destroy ]
      before_action -> { require_scope! :projects }, only: [ :create, :update, :destroy ]

      def index
        projects = current_workspace.projects.includes(:client).sorted_by_name

        render json: projects.map { |project| serialize_project(project) }
      end

      def show
        render json: serialize_project(@project)
      end

      def create
        project = current_workspace.projects.build(project_attrs)

        if project.save
          render json: serialize_project(project), status: :created
        else
          render_validation_error(project)
        end
      end

      def update
        if @project.update(project_attrs)
          render json: serialize_project(@project)
        else
          render_validation_error(@project)
        end
      end

      def destroy
        @project.destroy
        head :no_content
      end

      private

      def set_project
        @project = current_workspace.projects.find_by_hashid!(params[:id])
      end

      def project_attrs
        src = api_params(:project, :name, :client_id, :color, :billable_default)
        attrs = src.slice(:name, :color, :billable_default)
        if src.key?(:client_id)
          attrs[:client] = src[:client_id].present? ? find_referenced!(current_workspace.clients, :client_id, src[:client_id]) : nil
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
