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

        begin
          start_date = Date.parse(params[:start_date]) if params[:start_date].present?
          end_date = Date.parse(params[:end_date]) if params[:end_date].present?
        rescue ArgumentError
          return render json: { error: "unprocessable_entity", message: "start_date and end_date must be valid dates" }, status: :unprocessable_entity
        end

        time_entries = time_entries.where(start_at: start_date.beginning_of_day..) if start_date
        time_entries = time_entries.where(start_at: ..end_date.end_of_day) if end_date

        render json: time_entries.map { |time_entry| serialize_time_entry(time_entry) }
      end

      def show
        render json: serialize_time_entry(@time_entry)
      end

      def create
        require_scope!(:time_entries)
        return if performed?

        time_entry = current_user.time_entries.build(time_entry_attrs)
        time_entry.workspace = current_workspace

        if time_entry.save
          assign_tags(time_entry)
          render json: serialize_time_entry(time_entry), status: :created
        else
          render json: { error: "unprocessable_entity", message: time_entry.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:time_entries)
        return if performed?

        if @time_entry.update(time_entry_attrs)
          assign_tags(@time_entry)
          render json: serialize_time_entry(@time_entry)
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

        time_entry = current_user.time_entries.build(time_entry_attrs.merge(start_at: Time.current, end_at: nil))
        time_entry.workspace = current_workspace

        if time_entry.save
          assign_tags(time_entry)
          render json: serialize_time_entry(time_entry), status: :created
        else
          render json: { error: "unprocessable_entity", message: time_entry.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def stop
        require_scope!(:time_entries)
        return if performed?

        @time_entry.stop!
        render json: serialize_time_entry(@time_entry)
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

      # Accepts the documented field names (started_at/ended_at, hashid
      # project_id) and maps them onto the model's columns. The legacy
      # start_at/end_at names keep working.
      def time_entry_attrs
        src = api_params(:time_entry, :description, :project_id, :billable, :started_at, :ended_at, :start_at, :end_at, tag_ids: [])
        attrs = {}
        attrs[:description] = src[:description] if src.key?(:description)
        attrs[:billable] = src[:billable] if src.key?(:billable)
        attrs[:start_at] = src[:started_at] || src[:start_at] if src.key?(:started_at) || src.key?(:start_at)
        attrs[:end_at] = src[:ended_at] || src[:end_at] if src.key?(:ended_at) || src.key?(:end_at)
        if src.key?(:project_id)
          attrs[:project_id] = src[:project_id].present? ? current_workspace.projects.find_by!(id: Project.decode_id(src[:project_id].to_s)).id : nil
        end
        attrs
      end

      def tag_ids_param
        source = if params.key?(:tag_ids)
          params
        elsif params[:time_entry].is_a?(ActionController::Parameters) && params[:time_entry].key?(:tag_ids)
          params[:time_entry]
        end
        return nil if source.nil?

        Array(source[:tag_ids]).filter_map { |hashid| Tag.decode_id(hashid.to_s) }
      end

      def assign_tags(time_entry)
        ids = tag_ids_param
        return if ids.nil?

        time_entry.tags = current_workspace.tags.where(id: ids)
      end

      def serialize_time_entry(time_entry)
        {
          id: TimeEntry.encode_id(time_entry.id),
          description: time_entry.description,
          started_at: time_entry.start_at&.iso8601(3),
          ended_at: time_entry.end_at&.iso8601(3),
          duration_seconds: time_entry.duration,
          billable: time_entry.billable,
          project: time_entry.project && {
            id: Project.encode_id(time_entry.project.id),
            name: time_entry.project.name,
            color: time_entry.project.color
          },
          tags: time_entry.tags.map { |tag| { id: Tag.encode_id(tag.id), name: tag.name, color: nil } }
        }
      end
    end
  end
end
