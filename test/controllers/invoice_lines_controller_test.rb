require "test_helper"

class InvoiceLinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @workspace = workspaces(:one)
    @invoice = invoices(:one)
    @entry, @other_entry = 2.times.map do
      TimeEntry.create!(user: users(:one), workspace: @workspace, project: projects(:one), description: "Work", billable: true, start_at: 1.hour.ago, end_at: Time.current, duration_seconds: 3600)
    end
    @line = @invoice.invoice_lines.create!(time_entry: @entry, description: "Design", qty_hours: 2, rate_cents: 10_000, amount_cents: 20_000)
    @invoice.invoice_lines.create!(time_entry: @other_entry, description: "Build", qty_hours: 1, rate_cents: 10_000, amount_cents: 10_000)
    @invoice.update!(total_cents: 30_000)
  end

  test "editing a draft line recomputes its amount and the invoice total" do
    patch line_path, params: { line: { description: "Design review", qty_hours: "1.5", rate_cents: 12_345 } }

    assert_redirected_to "/#{@workspace.hashid}/invoices/#{@invoice.hashid}"
    @line.reload
    assert_equal "Design review", @line.description
    assert_equal 18_518, @line.amount_cents
    assert_equal 28_518, @invoice.reload.total_cents
  end

  test "lines on an issued invoice can't be edited or removed" do
    @invoice.update!(status: Invoice::STATUS_ISSUED)

    patch line_path, params: { line: { qty_hours: "5" } }
    assert_equal "Only draft invoices can be edited", flash[:alert]
    delete line_path

    assert_equal "Only draft invoices can be edited", flash[:alert]
    assert_equal 2, @line.reload.qty_hours
    assert_equal 30_000, @invoice.reload.total_cents
  end

  test "removing a line unbills its time entry and lowers the total" do
    assert_not TimeEntry.unbilled.exists?(@entry.id)

    delete line_path

    assert_not InvoiceLine.exists?(@line.id)
    assert TimeEntry.unbilled.exists?(@entry.id)
    assert_equal 10_000, @invoice.reload.total_cents
  end

  private

  def line_path
    "/#{@workspace.hashid}/invoices/#{@invoice.hashid}/lines/#{@line.id}"
  end
end
