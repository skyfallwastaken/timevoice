class OauthApplicationPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    workspace_member?
  end

  def create?
    workspace_admin?
  end

  def update?
    workspace_admin?
  end

  def destroy?
    workspace_admin?
  end

  private

  def workspace_member?
    record.workspace_id == workspace&.id
  end

  def workspace_admin?
    workspace_member? && workspace.admin?(user)
  end
end
