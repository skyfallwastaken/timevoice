class InvoicePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(workspace: user.workspaces)
    end
  end

  def index?
    user.current_workspace.present?
  end

  def show?
    user.current_workspace&.member?(user) && record.workspace_id == user.current_workspace&.id
  end

  def create?
    user.current_workspace&.admin?(user)
  end

  def update?
    user.current_workspace&.admin?(user) && record.workspace_id == user.current_workspace&.id
  end

  def destroy?
    update?
  end

  def send_email?
    update?
  end
end
