class TagsController < ApplicationController
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
    @tag = current_workspace.tags.find(params[:id])

    if @tag.update(tag_params)
      redirect_to tags_path, notice: "Tag updated successfully!"
    else
      redirect_to tags_path, alert: @tag.errors.full_messages.join(", ")
    end
  end

  def destroy
    @tag = current_workspace.tags.find(params[:id])
    @tag.destroy

    redirect_to tags_path, notice: "Tag deleted successfully!"
  end

  private

  def tag_params
    params.require(:tag).permit(:name)
  end
end
