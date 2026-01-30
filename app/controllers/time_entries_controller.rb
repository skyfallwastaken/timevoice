class TimeEntriesController < ApplicationController
  before_action :set_time_entry, only: [ :update, :destroy ]
  before_action :set_running_time_entry, only: [ :stop ]
  before_action :authorize_time_entry, only: [ :create, :update, :destroy, :stop ]

  def index
    @entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
      .order(start_at: :desc)
      .limit(50)

    render inertia: "TimeEntries/Index", props: {
      entries: @entries.map { |entry|
        entry.as_json(
          only: [ :id, :description, :start_at, :end_at, :duration_seconds, :billable ],
          include: {
            project: { only: [ :id, :name, :color ] },
            tags: { only: [ :id, :name ] }
          }
        ).merge(formattedDuration: entry.formatted_duration)
      }
    }
  end

  def create
    @time_entry = current_user.time_entries.build(time_entry_params)
    @time_entry.workspace = current_workspace

    if @time_entry.save
      # Attach tags if provided
      if params[:time_entry][:tag_ids].present?
        tag_ids = params[:time_entry][:tag_ids]
        valid_tags = current_workspace.tags.where(id: tag_ids)
        @time_entry.tags = valid_tags
      end

      redirect_to root_path, notice: "Timer started!"
    else
      redirect_to root_path, alert: @time_entry.errors.full_messages.join(", ")
    end
  end

  def update
    if @time_entry.update(time_entry_params)
      # Update tags if provided
      if params[:time_entry].key?(:tag_ids)
        tag_ids = params[:time_entry][:tag_ids] || []
        valid_tags = current_workspace.tags.where(id: tag_ids)
        @time_entry.tags = valid_tags
      end

      redirect_back(fallback_location: root_path, notice: "Entry updated!")
    else
      redirect_back(fallback_location: root_path, alert: @time_entry.errors.full_messages.join(", "))
    end
  end

  def destroy
    @time_entry.destroy

    redirect_back(fallback_location: root_path, notice: "Entry deleted!")
  end

  def stop
    @time_entry.stop!

    redirect_back(fallback_location: root_path, notice: "Timer stopped!")
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: root_path, alert: "No running timer found.")
  end

  private

  def set_time_entry
    @time_entry = current_user.time_entries.find(params[:id])
  end

  def set_running_time_entry
    @time_entry = current_user.time_entries.running.find(params[:id])
  end

  def authorize_time_entry
    authorize(@time_entry || TimeEntry.new(user: current_user, workspace: current_workspace))
  end

  def time_entry_params
    params.require(:time_entry).permit(:description, :project_id, :billable, :start_at, :end_at, tag_ids: [])
  end
end
