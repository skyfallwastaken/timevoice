class ApplicationMailer < ActionMailer::Base
  default from: Rails.app.creds.require(:smtp, :default_from)
  layout "mailer"
end
