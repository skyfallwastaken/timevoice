class WorkspacePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user.workspaces
    end
  end

  def show?
    record.member?(user)
  end

  def update?
    record.admin?(user)
  end

  def destroy?
    record.owner?(user)
  end

  def invite_member?
    admin?
  end

  def remove_member?
    admin?
  end

  def change_role?
    record.owner?(user)
  end
end
