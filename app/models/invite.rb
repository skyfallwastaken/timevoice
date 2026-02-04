class Invite < ApplicationRecord
  belongs_to :workspace
  belongs_to :inviter, class_name: "User"

  STATUSES = %w[pending accepted declined expired].freeze
  ROLES = %w[member admin].freeze

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_defaults, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :not_expired, -> { where("expires_at > ?", Time.current) }
  scope :valid, -> { pending.not_expired }

  def pending?
    status == "pending"
  end

  def expired?
    expires_at < Time.current
  end

  def accept!(user)
    return false unless pending? && !expired?

    transaction do
      update!(status: "accepted")
      workspace.memberships.create!(user: user, role: role)
    end
    true
  end

  def decline!
    return false unless pending?

    update!(status: "declined")
    true
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_defaults
    self.status ||= "pending"
    self.role ||= "member"
    self.expires_at ||= 7.days.from_now
  end
end
