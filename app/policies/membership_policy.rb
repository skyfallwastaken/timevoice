class MembershipPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(user: user).or(scope.where(workspace: user.workspaces))
    end
  end

  def show?
    record.user_id == user.id || record.workspace.member?(user)
  end

  def create?
    record.workspace.admin?(user)
  end

  def update?
    # Only workspace owner can change roles
    record.workspace.owner?(user)
  end

  def destroy?
    # Users can leave workspaces, owners can remove members
    record.user_id == user.id || record.workspace.admin?(user)
  end
end
