class ApplicationPolicy
  attr_reader :user_context, :record

  delegate :user, :workspace, to: :user_context

  def initialize(user_context, record)
    @user_context = user_context
    @record = record
  end

  def current_workspace
    workspace
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    attr_reader :user_context, :scope

    delegate :user, :workspace, to: :user_context

    def initialize(user_context, scope)
      @user_context = user_context
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    def current_workspace
      workspace
    end
  end
end
