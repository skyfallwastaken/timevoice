class ProjectsController < ApplicationController
  def index
    @projects = current_workspace.projects.includes(:client).order(:name)
    @clients = current_workspace.clients.order(:name)

    render inertia: "Projects/Index", props: {
      projects: @projects.map { |project|
        project.as_json(
          only: [ :id, :name, :color, :billable_default ],
          include: { client: { only: [ :id, :name ] } }
        )
      },
      clients: @clients.as_json(only: [ :id, :name ]),
      colors: Project::GRUVBOX_COLORS
    }
  end

  def create
    @project = current_workspace.projects.build(project_params)

    if @project.save
      redirect_to projects_path, notice: "Project created successfully!"
    else
      redirect_to projects_path, alert: @project.errors.full_messages.join(", ")
    end
  end

  def update
    @project = current_workspace.projects.find(params[:id])

    if @project.update(project_params)
      redirect_to projects_path, notice: "Project updated successfully!"
    else
      redirect_to projects_path, alert: @project.errors.full_messages.join(", ")
    end
  end

  def destroy
    @project = current_workspace.projects.find(params[:id])
    @project.destroy

    redirect_to projects_path, notice: "Project deleted successfully!"
  end

  private

  def project_params
    params.require(:project).permit(:name, :client_id, :color, :billable_default)
  end
end
