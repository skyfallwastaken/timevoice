require "prawn"
require "prawn/table"

class InvoicePdf
  def initialize(invoice, invoice_setting)
    @invoice = invoice
    @invoice_setting = invoice_setting
    @document = Prawn::Document.new(
      page_size: "A4",
      margin: [ 50, 50, 50, 50 ]
    )
    setup_fonts
  end

  def generate
    build_header
    build_invoice_details
    build_amount_due_section
    build_addresses
    build_line_items_table
    build_totals_section
    build_footer

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
    # Large "Invoice" title on the left
    @document.text "Invoice",
      size: 32,
      style: :bold,
      color: "000000"

    @document.move_down 25
  end

  def build_invoice_details
    # Invoice details in a table-like format
    details_data = [
      [ "Invoice number", invoice_number ],
      [ "Invoice date", format_date(@invoice.issued_on) ],
      [ "Period", "#{format_date(@invoice.period_start)} - #{format_date(@invoice.period_end)}" ]
    ]

    details_data.each do |label, value|
      @document.text "#{label}   #{value}",
        size: 10,
        color: "000000"
      @document.move_down 3
    end

    @document.move_down 30
  end

  def build_amount_due_section
    # Large amount due display
    amount_str = format_currency(@invoice.total_cents)

    @document.text "#{amount_str} USD",
      size: 22,
      style: :bold,
      color: "000000"

    @document.move_down 30
  end

  def build_addresses
    start_y = @document.cursor
    col_width = (@document.bounds.width / 2) - 20

    # Sender (left column)
    @document.bounding_box([ 0, start_y ], width: col_width) do
      sender_name = @invoice_setting&.sender_name || "Your Company"
      @document.text sender_name,
        size: 11,
        style: :bold,
        color: "000000"

      @document.move_down 5

      if @invoice_setting&.sender_address.present?
        @document.text @invoice_setting.sender_address,
          size: 10,
          color: "333333",
          leading: 4
      end
    end

    # Client (right column) - with "Bill to" label
    @document.bounding_box([ col_width + 40, start_y ], width: col_width) do
      @document.text "Bill to",
        size: 11,
        style: :bold,
        color: "000000"

      @document.move_down 5

      @document.text @invoice.client.name,
        size: 11,
        style: :bold,
        color: "000000"

      @document.move_down 5

      if @invoice.client.billing_address.present?
        @document.text @invoice.client.billing_address,
          size: 10,
          color: "333333",
          leading: 4
      end
    end

    # Calculate height of both columns and move cursor
    @document.move_cursor_to(start_y - 100)
  end

  def build_line_items_table
    @document.move_down 30

    # Build table data (no Qty column)
    table_data = [ [ "Description", "Hourly rate", "Amount" ] ]

    @invoice.invoice_lines.each do |line|
      hours = line.qty_hours || 0
      description = line.description || "No description"
      description_with_hours = "#{description} (#{format("%.2f", hours)} hrs)"

      table_data << [
        description_with_hours,
        format_currency(line.rate_cents),
        format_currency(line.amount_cents)
      ]
    end

    # Draw table with clean styling
    @document.table(table_data, width: @document.bounds.width) do |t|
      # Header styling
      t.row(0).font_style = :bold
      t.row(0).size = 10
      t.row(0).text_color = "000000"
      t.row(0).border_bottom_width = 1
      t.row(0).border_bottom_color = "000000"
      t.row(0).padding_bottom = 8

      # Data rows
      t.rows(1..-1).size = 10
      t.rows(1..-1).text_color = "000000"
      t.rows(1..-1).padding_top = 8
      t.rows(1..-1).padding_bottom = 8
      t.rows(1..-1).border_bottom_width = 0

      # Column alignments (columns 1 and 2 now, not 1..3)
      t.columns(1..2).align = :right

      # Minimal borders - only header underline
      t.cells.border_width = 0
      t.row(0).border_bottom_width = 1
    end

    @document.move_down 30
  end

  def build_totals_section
    totals_width = 250
    x_position = @document.bounds.width - totals_width

    # Build totals as a simple table for proper row alignment
    totals_data = [
      [ "Subtotal", format_currency(@invoice.total_cents) ],
      [ "Total", format_currency(@invoice.total_cents) ],
      [ "Amount due", "#{format_currency(@invoice.total_cents)} USD" ]
    ]

    @document.table(totals_data, position: x_position, width: totals_width) do |t|
      # All rows
      t.cells.border_width = 0
      t.cells.padding = [ 5, 0, 5, 0 ]
      t.cells.size = 10
      t.cells.color = "000000"

      # Right-align the amount column
      t.column(1).align = :right

      # Make the last row (Amount due) bold
      t.row(-1).font_style = :bold
      t.row(-1).size = 11

      # Add a line above Amount due
      t.row(-1).border_top_width = 1
      t.row(-1).border_top_color = "000000"
    end

    @document.move_down 40
  end

  def build_footer
    # Footer at bottom of page
    @document.bounding_box([ 0, 80 ], width: @document.bounds.width) do
      @document.stroke_horizontal_rule
      @document.move_down 15

      sender_name = @invoice_setting&.sender_name || "Your Company"
      @document.text "#{sender_name}",
        size: 9,
        color: "666666",
        align: :left
    end
  end

  def format_currency(cents)
    return "$0.00" if cents.nil?

    "$#{format("%.2f", cents / 100.0)}"
  end

  def format_date(date)
    return "N/A" if date.nil?

    date.strftime("%B %d, %Y")
  end

  def invoice_number
    # Format: 14B36550-0006 style
    "#{@invoice.id.to_s(16).upcase.rjust(8, '0')}-#{@invoice.id.to_s.rjust(4, '0')}"
  end
end
