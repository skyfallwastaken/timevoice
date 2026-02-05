class TimeEntriesController < ApplicationController
  before_action :set_time_entry, only: [ :update, :destroy, :remove_file ]
  before_action :set_running_time_entry, only: [ :stop ]
  before_action :authorize_time_entry, only: [ :create, :update, :destroy, :stop, :remove_file ]

  def create
    @time_entry = current_user.time_entries.build(time_entry_params)
    @time_entry.workspace = current_workspace

    if @time_entry.save

      if params[:time_entry][:tag_ids].present?
        tag_ids = Array(params[:time_entry][:tag_ids]).map(&:to_i)
        valid_tags = current_workspace.tags.where(id: tag_ids)

        if valid_tags.count != tag_ids.uniq.count
          invalid_count = tag_ids.uniq.count - valid_tags.count
          Rails.logger.warn("TimeEntriesController: #{invalid_count} invalid tag_ids provided by user #{current_user.id} in workspace #{current_workspace.id}")
        end

        @time_entry.tags = valid_tags
      end

      redirect_to root_path, notice: "Timer started!"
    else
      redirect_to root_path, alert: @time_entry.errors.full_messages.join(", ")
    end
  end

  def update
    if @time_entry.update(time_entry_params)

      if params[:time_entry].key?(:tag_ids)
        tag_ids = Array(params[:time_entry][:tag_ids]).map(&:to_i)
        valid_tags = current_workspace.tags.where(id: tag_ids)

        if valid_tags.count != tag_ids.uniq.count
          invalid_count = tag_ids.uniq.count - valid_tags.count
          Rails.logger.warn("TimeEntriesController: #{invalid_count} invalid tag_ids provided by user #{current_user.id} in workspace #{current_workspace.id}")
        end

        @time_entry.tags = valid_tags
      end

      if params[:time_entry][:files].present?
        @time_entry.files.attach(params[:time_entry][:files])
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

    if params[:time_entry] && params[:time_entry][:files].present?
      @time_entry.files.attach(params[:time_entry][:files])
    end

    redirect_back(fallback_location: root_path, notice: "Timer stopped!")
  end

  def remove_file
    file = @time_entry.files.find_by(blob_id: params[:blob_id])
    if file
      file.purge
      redirect_back(fallback_location: root_path, notice: "File removed!")
    else
      redirect_back(fallback_location: root_path, alert: "File not found.")
    end
  end

  private

  def set_time_entry
    @time_entry = current_user.time_entries.where(workspace: current_workspace).find(params[:id])
  end

  def set_running_time_entry
    @time_entry = current_user.time_entries.where(workspace: current_workspace).running.find_by(id: params[:id])
    unless @time_entry
      redirect_back(fallback_location: root_path, alert: "No running timer found in this workspace.") and return
    end
  end

  def authorize_time_entry
    authorize(@time_entry || TimeEntry.new(user: current_user, workspace: current_workspace))
  end

  def time_entry_params
    params.require(:time_entry).permit(:description, :project_id, :billable, :start_at, :end_at, tag_ids: [], files: [])
  end
end
