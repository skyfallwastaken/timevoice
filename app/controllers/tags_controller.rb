class TagsController < ApplicationController
  rate_limit to: 30, within: 1.minute, only: :create, with: -> {
    redirect_to tags_path, alert: "Too many tag creation attempts. Please wait a minute."
  }

  before_action :set_tag, only: [ :update, :destroy ]
  before_action :authorize_tag, only: [ :create, :update, :destroy ]

  def index
    @tags = current_workspace.tags.order(:name)

    render inertia: "Tags/Index", props: {
      tags: @tags.as_json(only: [ :id, :name ])
    }
  end

  def create
    @tag = current_workspace.tags.build(tag_params)

    if @tag.save
      redirect_to tags_path, notice: "Tag created successfully!"
    else
      redirect_to tags_path, alert: @tag.errors.full_messages.join(", ")
    end
  end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, notice: "Tag updated successfully!"
    else
      redirect_to tags_path, alert: @tag.errors.full_messages.join(", ")
    end
  end

  def destroy
    @tag.destroy

    redirect_to tags_path, notice: "Tag deleted successfully!"
  end

  private

  def set_tag
    @tag = current_workspace.tags.find(params[:id])
  end

  def authorize_tag
    authorize(@tag || Tag.new(workspace: current_workspace))
  end

  def tag_params
    params.require(:tag).permit(:name)
  end
end
