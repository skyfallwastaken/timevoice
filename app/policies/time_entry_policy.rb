class TimeEntryPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(user: user, workspace: current_workspace)
    end
  end

  def index?
    true
  end

  def show?
    record.user_id == user.id && record.workspace_id == current_workspace&.id
  end

  def create?
    current_workspace.present? && current_workspace.member?(user)
  end

  def update?
    record.user_id == user.id && record.workspace_id == current_workspace&.id
  end

  def destroy?
    update?
  end

  def stop?
    update?
  end

  def remove_file?
    update?
  end
end
