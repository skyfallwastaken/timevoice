class TimeEntriesController < ApplicationController
  include TagAssignable

  rate_limit to: 30, within: 1.minute, only: [ :create, :stop ], with: -> {
    redirect_back fallback_location: root_path, alert: "Too many time entry actions. Please wait a minute."
  }

  before_action :set_time_entry, only: [ :update, :destroy, :remove_file ]
  before_action :set_running_time_entry, only: [ :stop ]
  before_action :authorize_time_entry, only: [ :create, :update, :destroy, :stop, :remove_file ]
  before_action :set_selected_time_entries, only: [ :bulk_update, :bulk_destroy ]

  def create
    @time_entry = current_user.time_entries.build(time_entry_params)
    @time_entry.workspace = current_workspace

    if @time_entry.save_stopping_running_entries
      assign_tags_to_record(@time_entry, params[:time_entry][:tag_ids], current_workspace)
      redirect_back fallback_location: root_path, notice: @time_entry.running? ? "Timer started!" : "Entry created!"
    else
      redirect_back fallback_location: root_path, alert: @time_entry.errors.full_messages.join(", "), inertia: { errors: @time_entry.errors }
    end
  end

  def update
    attributes = time_entry_params
    # Assigning files replaces the attached ones, so pass those along with the uploads.
    attributes[:files] = @time_entry.files.blobs + attributes[:files] if attributes[:files].present?

    if @time_entry.update(attributes)
      if params[:time_entry].key?(:tag_ids)
        assign_tags_to_record(@time_entry, params[:time_entry][:tag_ids], current_workspace)
      end

      redirect_back(fallback_location: root_path, notice: "Entry updated!")
    else
      redirect_back(fallback_location: root_path, alert: @time_entry.errors.full_messages.join(", "), inertia: { errors: @time_entry.errors })
    end
  end

  def destroy
    @time_entry.destroy

    redirect_back(fallback_location: root_path, notice: "Entry deleted!")
  end

  def bulk_update
    changes = params.fetch(:changes, {}).permit(:project_id, :billable, add_tag_ids: [])
    attributes = {}
    if changes.key?(:project_id)
      attributes[:project] = changes[:project_id].present? ? current_workspace.projects.find(changes[:project_id]) : nil
    end
    attributes[:billable] = ActiveModel::Type::Boolean.new.cast(changes[:billable]) if changes.key?(:billable)
    added_tags = current_workspace.tags.where(id: changes[:add_tag_ids])

    TimeEntry.transaction do
      @time_entries.each do |entry|
        entry.update!(attributes)
        entry.tags << (added_tags - entry.tags)
      end
    end

    redirect_back fallback_location: root_path, notice: "#{helpers.pluralize(@time_entries.size, 'entry')} updated!"
  rescue ActiveRecord::RecordInvalid => e
    message = e.record.errors.full_messages.join(", ")
    redirect_back fallback_location: root_path, alert: message, inertia: { errors: { base: message } }
  end

  def bulk_destroy
    TimeEntry.transaction { @time_entries.each(&:destroy!) }

    redirect_back fallback_location: root_path, notice: "#{helpers.pluralize(@time_entries.size, 'entry')} deleted!"
  end

  def stop
    @time_entry.stop!(at: requested_end_at)

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

  def workspace_entries
    current_user.time_entries.where(workspace: current_workspace)
  end

  def set_selected_time_entries
    @time_entries = workspace_entries.where(id: Array(params[:ids])).includes(:tags).to_a
    @time_entries.each { |entry| authorize entry, :update? }
  end

  def set_time_entry
    @time_entry = workspace_entries.find(params[:id])
  end

  def set_running_time_entry
    @time_entry = workspace_entries.running.find_by(id: params[:id])
    unless @time_entry
      redirect_back(fallback_location: root_path, alert: "No running timer found in this workspace.") and return
    end
  end

  def authorize_time_entry
    authorize(@time_entry || TimeEntry.new(user: current_user, workspace: current_workspace))
  end

  # A countdown sends the time it was due to end, so a late stop
  # (a throttled or closed tab) doesn't record extra time.
  def requested_end_at
    Time.zone.parse(params.dig(:time_entry, :end_at).to_s)
  rescue ArgumentError
    nil
  end

  def time_entry_params
    params.require(:time_entry).permit(:description, :project_id, :billable, :start_at, :end_at, tag_ids: [], files: [])
  end
end
