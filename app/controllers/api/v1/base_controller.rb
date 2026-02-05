# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization

      before_action :doorkeeper_authorize!

      rescue_from Pundit::NotAuthorizedError, with: :forbidden
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def current_user
        @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
      end

      def current_workspace
        @current_workspace ||= begin
          if params[:workspace_id].present?
            current_user&.workspaces&.find_by_hashid(params[:workspace_id])
          else
            current_user&.workspaces&.first
          end
        end
      end

      def require_workspace!
        not_found unless current_workspace
      end

      def pundit_user
        UserContext.new(current_user, current_workspace)
      end

      def require_scope!(*scopes)
        required = scopes.map(&:to_s)
        present = doorkeeper_token.scopes.to_a

        unless (required & present).any?
          render json: { error: "insufficient_scope", error_description: "Required scope: #{required.join(' or ')}" }, status: :forbidden
        end
      end

      def forbidden(exception = nil)
        render json: { error: "forbidden", message: exception&.message || "You are not authorized to perform this action" }, status: :forbidden
      end

      def not_found
        render json: { error: "not_found", message: "Resource not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: "unprocessable_entity", message: exception.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end
  end
end
