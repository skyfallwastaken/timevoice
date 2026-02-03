class InvoiceMailer < ApplicationMailer
  def send_invoice(invoice:, recipients:, cc:, message:)
    @invoice = invoice
    @message = message
    @sender_name = invoice.workspace.invoice_setting&.sender_name || "Your Company"

    pdf = InvoicePdf.new(invoice, invoice.workspace.invoice_setting).generate
    @filename = invoice_filename(invoice)

    attachments[@filename] = {
      mime_type: "application/pdf",
      content: pdf
    }

    mail(
      from: "timevoice@mahadk.com",
      to: recipients,
      cc: cc.presence,
      subject: "You received a #{invoice.formatted_total} invoice from #{@sender_name}"
    )
  end

  private

  def invoice_filename(invoice)
    client_name = invoice.client.name.parameterize
    date_range = "#{invoice.period_start.strftime('%Y%m%d')}-#{invoice.period_end.strftime('%Y%m%d')}"
    "invoice-#{client_name}-#{date_range}.pdf"
  end
end
