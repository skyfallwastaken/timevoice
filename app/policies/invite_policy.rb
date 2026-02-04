class InvitePolicy < ApplicationPolicy
  def destroy?
    record.workspace.admin?(user)
  end
end
