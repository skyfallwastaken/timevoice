# frozen_string_literal: true

module Api
  module V1
    class TimeEntriesController < BaseController
      before_action :require_workspace!
      before_action :set_time_entry, only: [ :show, :update, :destroy ]
      before_action :set_running_time_entry, only: [ :stop ]
      before_action -> { require_scope! :time_entries }, only: [ :create, :update, :destroy, :start, :stop ]

      def index
        time_entries = current_user.time_entries
          .where(workspace: current_workspace)
          .includes(:project, :tags)
          .order(start_at: :desc)

        begin
          start_date = Date.iso8601(params[:start_date]) if params[:start_date].present?
          end_date = Date.iso8601(params[:end_date]) if params[:end_date].present?
        rescue ArgumentError
          return render json: { error: "unprocessable_entity", message: "start_date and end_date must be valid dates" }, status: :unprocessable_entity
        end

        time_entries = time_entries.where(start_at: start_date.beginning_of_day..) if start_date
        time_entries = time_entries.where(start_at: ..end_date.end_of_day) if end_date
        case ActiveModel::Type::Boolean.new.cast(params[:running])
        when true then time_entries = time_entries.running
        when false then time_entries = time_entries.where.not(end_at: nil)
        end

        render json: time_entries.map { |time_entry| serialize_time_entry(time_entry) }
      end

      def show
        render json: serialize_time_entry(@time_entry)
      end

      def create
        time_entry = current_user.time_entries.build(time_entry_attrs)
        time_entry.workspace = current_workspace

        if time_entry.save_stopping_running_entries
          render json: serialize_time_entry(time_entry), status: :created
        else
          render_validation_error(time_entry)
        end
      end

      def update
        if @time_entry.update(time_entry_attrs)
          render json: serialize_time_entry(@time_entry)
        else
          render_validation_error(@time_entry)
        end
      end

      def destroy
        @time_entry.destroy
        head :no_content
      end

      def start
        time_entry = current_user.time_entries.build(time_entry_attrs.merge(start_at: Time.current, end_at: nil))
        time_entry.workspace = current_workspace

        if time_entry.save_stopping_running_entries
          render json: serialize_time_entry(time_entry), status: :created
        else
          render_validation_error(time_entry)
        end
      end

      def stop
        @time_entry.stop!
        render json: serialize_time_entry(@time_entry)
      end

      private

      def set_time_entry
        @time_entry = current_user.time_entries.where(workspace: current_workspace).find_by_hashid!(params[:id])
      end

      def set_running_time_entry
        @time_entry = current_user.time_entries.where(workspace: current_workspace).running.find_by_hashid!(params[:id])
      end

      # Accepts the documented field names (started_at/ended_at, hashid
      # project_id) and maps them onto the model's columns. The legacy
      # start_at/end_at names keep working.
      def time_entry_attrs
        src = api_params(:time_entry, :description, :project_id, :billable, :started_at, :ended_at, :start_at, :end_at, tag_ids: [])
        attrs = src.slice(:description, :billable)
        attrs[:start_at] = parse_time!(:started_at, src[:started_at] || src[:start_at]) if src.key?(:started_at) || src.key?(:start_at)
        attrs[:end_at] = parse_time!(:ended_at, src[:ended_at] || src[:end_at]) if src.key?(:ended_at) || src.key?(:end_at)
        if src.key?(:project_id)
          attrs[:project] = src[:project_id].present? ? find_referenced!(current_workspace.projects, :project_id, src[:project_id]) : nil
        end
        if src.key?(:tag_ids)
          attrs[:tags] = Array(src[:tag_ids]).uniq.map { |hashid| find_referenced!(current_workspace.tags, :tag_ids, hashid) }
        end
        attrs
      end

      def parse_time!(field, value)
        return if value.blank?

        Time.zone.parse(value.to_s) || raise(InvalidParameter, "#{field} must be a valid date-time")
      rescue ArgumentError
        raise InvalidParameter, "#{field} must be a valid date-time"
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
