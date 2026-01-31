# frozen_string_literal: true

class WorkspaceResourcePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(workspace: user.workspaces)
    end
  end

  def index?
    user.current_workspace.present?
  end

  def create?
    user.current_workspace&.member?(user)
  end

  def update?
    user.current_workspace&.member?(user) && record.workspace_id == user.current_workspace&.id
  end

  def destroy?
    update?
  end
end
