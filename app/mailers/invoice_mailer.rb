class InvoiceMailer < ApplicationMailer
  def send_invoice(invoice:, recipients:, cc:, message:)
    @invoice = invoice
    @message = message
    @sender_name = invoice.workspace.invoice_setting&.sender_name || "Your Company"

    pdf = InvoicePdf.new(invoice, invoice.workspace.invoice_setting).generate
    @filename = invoice.filename("pdf")

    attachments[@filename] = {
      mime_type: "application/pdf",
      content: pdf
    }

    mail(
      to: recipients,
      cc: cc.presence,
      subject: "You received a #{invoice.formatted_total} invoice from #{@sender_name}"
    )
  end
end
