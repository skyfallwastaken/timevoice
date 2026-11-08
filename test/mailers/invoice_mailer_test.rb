require "test_helper"

class InvoiceMailerTest < ActionMailer::TestCase
  test "the attached PDF is named like a downloaded invoice" do
    invoice = invoices(:one)
    invoice.client.update!(name: "Acme Corp")
    invoice.update!(period_start: Date.new(2026, 1, 1), period_end: Date.new(2026, 1, 31))

    mail = InvoiceMailer.send_invoice(invoice: invoice, recipients: [ "billing@example.com" ], cc: [], message: "")

    assert_equal [ "Invoice to Acme Corp - Jan 01, 2026 - Jan 31, 2026.pdf" ], mail.attachments.map(&:filename)
  end
end
