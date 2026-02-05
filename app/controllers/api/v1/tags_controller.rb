# frozen_string_literal: true

module Api
  module V1
    class TagsController < BaseController
      before_action :require_workspace!
      before_action :set_tag, only: [ :show, :update, :destroy ]

      def index
        tags = current_workspace.tags.order(:name)

        render json: tags.as_json(only: [ :id, :name ])
      end

      def show
        render json: @tag.as_json(only: [ :id, :name ])
      end

      def create
        require_scope!(:tags)
        return if performed?

        tag = current_workspace.tags.build(tag_params)

        if tag.save
          render json: tag.as_json(only: [ :id, :name ]), status: :created
        else
          render json: { error: "unprocessable_entity", message: tag.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:tags)
        return if performed?

        if @tag.update(tag_params)
          render json: @tag.as_json(only: [ :id, :name ])
        else
          render json: { error: "unprocessable_entity", message: @tag.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        require_scope!(:tags)
        return if performed?

        @tag.destroy
        head :no_content
      end

      private

      def set_tag
        @tag = current_workspace.tags.find(params[:id])
      end

      def tag_params
        params.require(:tag).permit(:name)
      end
    end
  end
end
