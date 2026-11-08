require "test_helper"
require "pdf/reader"

class InvoicePdfTest < ActiveSupport::TestCase
  test "renders notes as markdown, keeping typed line breaks" do
    lines = notes_pdf_lines(<<~MD)
      Payment due **within 30 days**.
      Bank: Monzo, ref INV\\_2026

      - Sort code: `04-00-04`
      - [Pay online](https://pay.example.com) or [not this](javascript:alert(1))

      2026. Thanks
    MD

    assert_includes lines, "Payment due within 30 days."
    assert_includes lines, "Bank: Monzo, ref INV_2026"
    assert_includes lines, "• Sort code: 04-00-04"
    assert_includes lines, "• Pay online or not this"
    assert_includes lines, "2026. Thanks"
    assert_equal [ "https://pay.example.com" ], @links
  end

  test "deeply nested notes still render" do
    lines = notes_pdf_lines("#{"> - " * 25}deep")

    assert lines.any? { |line| line.end_with?("deep") }
  end

  test "omits the notes section when notes are blank" do
    assert_not_includes notes_pdf_lines("  "), "Notes"
  end

  private

  def notes_pdf_lines(notes)
    setting = invoice_settings(:one)
    setting.notes = notes

    reader = PDF::Reader.new(StringIO.new(InvoicePdf.new(invoices(:one), setting).generate))
    objects = reader.objects
    @links = reader.pages.flat_map { |page| Array(objects.deref(page.attributes[:Annots])) }
      .filter_map { |annot| objects.deref(objects.deref(annot)[:A])&.dig(:URI) }

    reader.pages.map(&:text).join("\n").lines.map(&:squish)
  end
end
