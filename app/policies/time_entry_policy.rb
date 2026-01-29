class TimeEntryPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(user: user, workspace: user.current_workspace)
    end
  end

  def index?
    true
  end

  def show?
    record.user_id == user.id && record.workspace_id == user.current_workspace&.id
  end

  def create?
    user.current_workspace.present? && user.current_workspace.member?(user)
  end

  def update?
    record.user_id == user.id && record.workspace_id == user.current_workspace&.id
  end

  def destroy?
    update?
  end

  def stop?
    update?
  end
end
