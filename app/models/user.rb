class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :owned_workspaces, class_name: "Workspace", foreign_key: :owner_id, dependent: :nullify
  has_many :time_entries, dependent: :destroy
  belongs_to :last_used_workspace, class_name: "Workspace", optional: true

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :google_uid, presence: true, uniqueness: true

  def self.from_omniauth(auth)
    user = find_by(google_uid: auth.uid)

    if user
      user.update(
        name: auth.info.name,
        email: auth.info.email,
        avatar_url: auth.info.image
      )
    else
      user = create(
        google_uid: auth.uid,
        name: auth.info.name,
        email: auth.info.email,
        avatar_url: auth.info.image,
        timezone: "UTC"
      )
    end

    user
  end

  def create_default_workspace
    return if workspaces.any?

    workspace = Workspace.create!(
      name: "#{name}'s Workspace",
      owner: self
    )

    Membership.create!(
      user: self,
      workspace: workspace,
      role: "owner"
    )

    workspace
  end

  def current_workspace
    @current_workspace ||= workspaces.first
  end
end
