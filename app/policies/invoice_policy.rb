class InvoicePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where(workspace: current_workspace)
    end
  end

  def index?
    current_workspace.present?
  end

  def show?
    current_workspace&.member?(user) && record.workspace_id == current_workspace&.id
  end

  def create?
    current_workspace&.admin?(user)
  end

  def update?
    current_workspace&.admin?(user) && record.workspace_id == current_workspace&.id
  end

  def destroy?
    update?
  end

  def send_email?
    update?
  end
end
