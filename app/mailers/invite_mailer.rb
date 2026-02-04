class InviteMailer < ApplicationMailer
  def workspace_invite(invite:)
    @invite = invite
    @workspace = invite.workspace
    @inviter = invite.inviter
    @is_new_user = !User.exists?(email: invite.email.downcase)
    @accept_url = invite_url(token: invite.token)

    mail(
      to: invite.email,
      subject: "#{@inviter.name} invited you to join #{@workspace.name} on Timevoice"
    )
  end
end
