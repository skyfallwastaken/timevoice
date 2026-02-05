# frozen_string_literal: true

module Api
  module V1
    class TimeEntriesController < BaseController
      before_action :require_workspace!
      before_action :set_time_entry, only: [ :show, :update, :destroy ]
      before_action :set_running_time_entry, only: [ :stop ]

      def index
        time_entries = current_user.time_entries
          .where(workspace: current_workspace)
          .includes(:project, :tags)
          .order(start_at: :desc)

        render json: time_entries.as_json(
          only: [ :id, :description, :billable, :start_at, :end_at ],
          include: {
            project: { only: [ :id, :name, :color ] },
            tags: { only: [ :id, :name ] }
          }
        )
      end

      def show
        render json: @time_entry.as_json(
          only: [ :id, :description, :billable, :start_at, :end_at ],
          include: {
            project: { only: [ :id, :name, :color ] },
            tags: { only: [ :id, :name ] }
          }
        )
      end

      def create
        require_scope!(:time_entries)
        return if performed?

        time_entry = current_user.time_entries.build(time_entry_params)
        time_entry.workspace = current_workspace

        if time_entry.save
          assign_tags(time_entry)
          render json: time_entry.as_json(
            only: [ :id, :description, :billable, :start_at, :end_at ],
            include: {
              project: { only: [ :id, :name, :color ] },
              tags: { only: [ :id, :name ] }
            }
          ), status: :created
        else
          render json: { error: "unprocessable_entity", message: time_entry.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:time_entries)
        return if performed?

        if @time_entry.update(time_entry_params)
          assign_tags(@time_entry) if params[:time_entry]&.key?(:tag_ids)
          render json: @time_entry.as_json(
            only: [ :id, :description, :billable, :start_at, :end_at ],
            include: {
              project: { only: [ :id, :name, :color ] },
              tags: { only: [ :id, :name ] }
            }
          )
        else
          render json: { error: "unprocessable_entity", message: @time_entry.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        require_scope!(:time_entries)
        return if performed?

        @time_entry.destroy
        head :no_content
      end

      def start
        require_scope!(:time_entries)
        return if performed?

        time_entry = current_user.time_entries.build(time_entry_params.merge(start_at: Time.current))
        time_entry.workspace = current_workspace

        if time_entry.save
          assign_tags(time_entry)
          render json: time_entry.as_json(
            only: [ :id, :description, :billable, :start_at, :end_at ],
            include: {
              project: { only: [ :id, :name, :color ] },
              tags: { only: [ :id, :name ] }
            }
          ), status: :created
        else
          render json: { error: "unprocessable_entity", message: time_entry.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def stop
        require_scope!(:time_entries)
        return if performed?

        @time_entry.stop!
        render json: @time_entry.as_json(
          only: [ :id, :description, :billable, :start_at, :end_at ],
          include: {
            project: { only: [ :id, :name, :color ] },
            tags: { only: [ :id, :name ] }
          }
        )
      end

      private

      def set_time_entry
        time_entry_id = TimeEntry.decode_id(params[:id])
        @time_entry = current_user.time_entries.where(workspace: current_workspace).find_by!(id: time_entry_id)
      end

      def set_running_time_entry
        time_entry_id = TimeEntry.decode_id(params[:id])
        @time_entry = current_user.time_entries.where(workspace: current_workspace).running.find_by!(id: time_entry_id)
      end

      def time_entry_params
        params.require(:time_entry).permit(:description, :project_id, :billable, :start_at, :end_at, tag_ids: [])
      end

      def assign_tags(time_entry)
        return unless params[:time_entry]&.key?(:tag_ids)

        tag_ids = Array(params[:time_entry][:tag_ids]).compact
        tags = current_workspace.tags.where(id: tag_ids)
        time_entry.tags = tags
      end
    end
  end
end
