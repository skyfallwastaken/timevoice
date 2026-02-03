class SendInvoiceEmailJob < ApplicationJob
  queue_as :default

  def perform(invoice_id:, recipients:, cc:, message:)
    invoice = Invoice.find(invoice_id)

    InvoiceMailer.send_invoice(
      invoice: invoice,
      recipients: recipients,
      cc: cc,
      message: message
    ).deliver_now
  end
end
