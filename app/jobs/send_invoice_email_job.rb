class SendInvoiceEmailJob < ApplicationJob
  queue_as :default

  def perform(invoice_id:, recipients:, cc:, sender_email:, message:)
    invoice = Invoice.find(invoice_id)

    InvoiceMailer.send_invoice(
      invoice: invoice,
      recipients: recipients,
      cc: cc,
      sender_email: sender_email,
      message: message
    ).deliver_now
  end
end
