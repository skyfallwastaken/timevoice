class Membership < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  validates :role, inclusion: { in: %w[owner admin member] }
  validates :user_id, uniqueness: { scope: :workspace_id }

  def owner?
    role == "owner"
  end

  def admin?
    role == "admin" || owner?
  end

  def member?
    role == "member" || admin?
  end
end
