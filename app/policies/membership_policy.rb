class MembershipPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(workspace: current_workspace)
    end
  end

  def show?
    record.user_id == user.id || record.workspace.member?(user)
  end

  def create?
    record.workspace.admin?(user)
  end

  def update?
    record.workspace.owner?(user)
  end

  def destroy?
    record.user_id == user.id || record.workspace.admin?(user)
  end
end
