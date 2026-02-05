class UserContext
  attr_reader :user, :workspace

  delegate :id, :admin?, :workspaces, to: :user, allow_nil: true

  def initialize(user, workspace)
    @user = user
    @workspace = workspace
  end

  def current_workspace
    workspace
  end
end
