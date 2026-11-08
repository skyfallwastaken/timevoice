# frozen_string_literal: true

module Api
  module V1
    class TagsController < BaseController
      before_action :require_workspace!
      before_action :set_tag, only: [ :show, :update, :destroy ]

      def index
        tags = current_workspace.tags.order(:name)

        render json: tags.map { |tag| serialize_tag(tag) }
      end

      def show
        render json: serialize_tag(@tag)
      end

      def create
        require_scope!(:tags)
        return if performed?

        tag = current_workspace.tags.build(tag_attrs)

        if tag.save
          render json: serialize_tag(tag), status: :created
        else
          render json: { error: "unprocessable_entity", message: tag.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:tags)
        return if performed?

        if @tag.update(tag_attrs)
          render json: serialize_tag(@tag)
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
        tag_id = Tag.decode_id(params[:id])
        @tag = current_workspace.tags.find_by!(id: tag_id)
      end

      def tag_attrs
        api_params(:tag, :name)
      end

      def serialize_tag(tag)
        # Tags don't have a color column (yet) — documented as nullable.
        { id: Tag.encode_id(tag.id), name: tag.name, color: nil }
      end
    end
  end
end
