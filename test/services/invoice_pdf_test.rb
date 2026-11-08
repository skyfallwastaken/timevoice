require "test_helper"
require "pdf/reader"

class InvoicePdfTest < ActiveSupport::TestCase
  test "renders notes as markdown, keeping typed line breaks" do
    setting = invoice_settings(:one)
    setting.notes = <<~MD
      Payment due **within 30 days**.
      Bank: Monzo

      - Sort code: `04-00-04`
      - [Pay online](https://pay.example.com) or [not this](javascript:alert(1))
    MD

    reader = PDF::Reader.new(StringIO.new(InvoicePdf.new(invoices(:one), setting).generate))
    lines = reader.pages.map(&:text).join("\n").lines.map(&:squish)

    assert_includes lines, "Payment due within 30 days."
    assert_includes lines, "Bank: Monzo"
    assert_includes lines, "• Sort code: 04-00-04"
    assert_includes lines, "• Pay online or not this"

    objects = reader.objects
    links = reader.pages.flat_map { |page| Array(objects.deref(page.attributes[:Annots])) }
      .filter_map { |annot| objects.deref(objects.deref(annot)[:A])&.dig(:URI) }
    assert_equal [ "https://pay.example.com" ], links
  end

  test "omits the notes section when notes are blank" do
    setting = invoice_settings(:one)
    setting.notes = "  "

    text = PDF::Reader.new(StringIO.new(InvoicePdf.new(invoices(:one), setting).generate)).pages.map(&:text).join

    assert_not_includes text, "Notes"
  end
end
