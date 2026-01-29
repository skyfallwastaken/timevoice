require "prawn"
require "prawn/table"

class InvoicePdf
  BRAND_COLOR = "6366F1"
  TEXT_PRIMARY = "1A1A1A"
  TEXT_SECONDARY = "666666"
  TEXT_MUTED = "999999"
  BORDER_COLOR = "EEEEEE"

  def initialize(invoice, invoice_setting)
    @invoice = invoice
    @invoice_setting = invoice_setting
    @document = Prawn::Document.new(
      page_size: "A4",
      margin: [ 60, 60, 60, 60 ]
    )
    setup_fonts
  end

  def generate
    build_header
    build_invoice_meta
    build_addresses
    build_line_items_table
    build_totals_section

    @document.render
  end

  private

  def setup_fonts
    font_path = Rails.root.join("app", "assets", "fonts")

    @document.font_families.update(
      "PublicSans" => {
        normal: File.join(font_path, "PublicSans-Regular.ttf"),
        bold: File.join(font_path, "PublicSans-Bold.ttf")
      }
    )

    @document.font "PublicSans"
  end

  def build_header
    sender_name = @invoice_setting&.sender_name || "Your Company"

    @document.text "INVOICE",
      size: 11,
      color: TEXT_SECONDARY,
      character_spacing: 1.5

    @document.move_down 6

    @document.text sender_name,
      size: 28,
      style: :bold,
      color: TEXT_PRIMARY

    @document.move_down 20
  end

  def build_invoice_meta
    col_width = @document.bounds.width / 3

    @document.bounding_box([ 0, @document.cursor ], width: @document.bounds.width, height: 35) do
      [ [ "Invoice #", invoice_number, 0 ],
        [ "Issue Date", format_date(@invoice.issued_on), col_width ],
        [ "Period", "#{format_date(@invoice.period_start)} – #{format_date(@invoice.period_end)}", col_width * 2 ]
      ].each do |label, value, x_pos|
        @document.bounding_box([ x_pos, @document.bounds.top ], width: col_width) do
          @document.text label, size: 9, color: TEXT_SECONDARY
          @document.move_down 2
          @document.text value, size: 10, color: TEXT_PRIMARY, style: :bold
        end
      end
    end

    @document.move_down 20
  end

  def build_addresses
    start_y = @document.cursor
    col_width = (@document.bounds.width / 2) - 15

    @document.bounding_box([ 0, start_y ], width: col_width) do
      @document.text "From",
        size: 10,
        color: TEXT_SECONDARY

      @document.move_down 8

      sender_name = @invoice_setting&.sender_name || "Your Company"
      @document.text sender_name,
        size: 12,
        style: :bold,
        color: TEXT_PRIMARY

      @document.move_down 6

      if @invoice_setting&.sender_address.present?
        @document.text @invoice_setting.sender_address,
          size: 9,
          color: TEXT_SECONDARY,
          leading: 4
      end
    end

    @document.bounding_box([ col_width + 30, start_y ], width: col_width) do
      @document.text "Bill To",
        size: 9,
        color: TEXT_SECONDARY

      @document.move_down 8

      @document.text @invoice.client.name,
        size: 12,
        style: :bold,
        color: TEXT_PRIMARY

      @document.move_down 6

      if @invoice.client.billing_address.present?
        @document.text @invoice.client.billing_address,
          size: 10,
          color: TEXT_SECONDARY,
          leading: 4
      end
    end

    @document.move_cursor_to(start_y - 100)
  end

  def build_line_items_table
    @document.move_down 35

    @document.stroke_color BORDER_COLOR
    @document.stroke_horizontal_rule
    @document.move_down 25

    @document.text "Line Items",
      size: 14,
      style: :bold,
      color: TEXT_PRIMARY

    @document.move_down 15

    table_data = [ [ "Description", "Rate", "Hours", "Amount" ] ]

    @invoice.invoice_lines.each do |line|
      hours = line.qty_hours || 0
      description = sanitize_text(line.description) || "No description"

      table_data << [
        description,
        format_currency(line.rate_cents),
        format("%.2f", hours),
        format_currency(line.amount_cents)
      ]
    end

    @document.table(table_data, width: @document.bounds.width) do |t|
      t.cells.border_width = 0
      t.cells.padding = [ 10, 0, 10, 0 ]

      t.row(0).font_style = :bold
      t.row(0).size = 10
      t.row(0).text_color = TEXT_SECONDARY
      t.row(0).border_bottom_width = 1
      t.row(0).border_bottom_color = BORDER_COLOR

      t.rows(1..-1).size = 10
      t.rows(1..-1).text_color = TEXT_PRIMARY
      t.rows(1..-1).border_bottom_width = 1
      t.rows(1..-1).border_bottom_color = "F5F5F5"

      t.columns(1..3).align = :right
      t.column(0).width = @document.bounds.width * 0.45
    end

    @document.move_down 25
  end

  def build_totals_section
    totals_width = 200

    totals_data = [
      [ "Subtotal", format_currency(@invoice.total_cents) ],
      [ "Total Due", "#{format_currency(@invoice.total_cents)} USD" ]
    ]

    @document.bounding_box([ @document.bounds.width - totals_width, @document.cursor ], width: totals_width) do
      @document.table(totals_data, width: totals_width) do |t|
        t.cells.border_width = 0
        t.cells.padding = [ 6, 0, 6, 0 ]
        t.cells.size = 10

        t.column(0).text_color = TEXT_SECONDARY
        t.column(1).text_color = TEXT_PRIMARY
        t.column(1).align = :right

        t.row(-1).font_style = :bold
        t.row(-1).size = 12
        t.row(-1).text_color = TEXT_PRIMARY
        t.row(-1).border_top_width = 1
        t.row(-1).border_top_color = BORDER_COLOR
        t.row(-1).padding_top = 10
      end
    end
  end

  def format_currency(cents)
    return "$0.00" if cents.nil?

    "$#{format("%.2f", cents / 100.0)}"
  end

  def format_date(date)
    return "N/A" if date.nil?

    date.strftime("%b %d, %Y")
  end

  def invoice_number
    "#{@invoice.id.to_s(16).upcase.rjust(8, '0')}-#{@invoice.id.to_s.rjust(4, '0')}"
  end

  def sanitize_text(text)
    return nil if text.nil?

    text
      .gsub(/\x00/, "")
      .gsub(/[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
      .strip
  end
end
