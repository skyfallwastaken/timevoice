# frozen_string_literal: true

module Api
  module V1
    class TagsController < BaseController
      before_action :require_workspace!
      before_action :set_tag, only: [ :show, :update, :destroy ]
      before_action -> { require_scope! :tags }, only: [ :create, :update, :destroy ]

      def index
        tags = current_workspace.tags.sorted_by_name

        render json: tags.map { |tag| serialize_tag(tag) }
      end

      def show
        render json: serialize_tag(@tag)
      end

      def create
        tag = current_workspace.tags.build(tag_attrs)

        if tag.save
          render json: serialize_tag(tag), status: :created
        else
          render_validation_error(tag)
        end
      end

      def update
        if @tag.update(tag_attrs)
          render json: serialize_tag(@tag)
        else
          render_validation_error(@tag)
        end
      end

      def destroy
        @tag.destroy
        head :no_content
      end

      private

      def set_tag
        @tag = current_workspace.tags.find_by_hashid!(params[:id])
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
