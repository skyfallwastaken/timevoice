class InvitePolicy < ApplicationPolicy
  def show?
    record.pending?
  end

  def destroy?
    record.workspace.admin?(user)
  end
end
