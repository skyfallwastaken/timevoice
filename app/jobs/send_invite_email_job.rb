class SendInviteEmailJob < ApplicationJob
  queue_as :default

  def perform(invite_id:)
    invite = Invite.find_by(id: invite_id)
    return unless invite&.pending?

    InviteMailer.workspace_invite(invite: invite).deliver_now
  end
end
