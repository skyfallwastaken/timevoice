require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  test "deleting its workspace still deletes an issued invoice" do
    invoice = invoices(:one)
    invoice.update!(status: "issued")

    assert_not invoice.destroy
    invoice.workspace.destroy!

    assert_not Invoice.exists?(invoice.id)
  end

  test "a refused delete keeps the invoice's lines, even inside an outer transaction" do
    invoice = invoices(:one)
    invoice.update!(status: "issued")
    invoice.invoice_lines.create!(description: "Work", qty_hours: 1, rate_cents: 100, amount_cents: 100, time_entry: time_entries(:one))

    Invoice.transaction { assert_not invoice.destroy }

    assert_equal 1, invoice.invoice_lines.count
  end

  test "an invoice can't be renumbered to a blank or taken number" do
    invoice = invoices(:one)
    invoices(:two).update!(workspace: invoice.workspace)

    assert_not invoice.update(invoice_number: invoices(:two).invoice_number)
    assert_not invoice.update(invoice_number: "")
  end

  test "only a draft can be renumbered" do
    invoice = invoices(:one)
    [ Invoice::STATUS_PAID, Invoice::STATUS_ISSUED ].each do |status|
      invoice.update!(status: status)

      assert_not invoice.update(invoice_number: 7)
      assert_equal 1, invoice.reload.invoice_number
    end

    invoice.update!(status: Invoice::STATUS_DRAFT)
    invoice.update!(invoice_number: 7)
    assert_equal 7, invoice.reload.invoice_number
  end

  test "generate_from_time_entries filters to the provided user and keeps the notes it was created with" do
    owner = User.create!(
      email: "invoice-owner@example.com",
      name: "Invoice Owner",
      google_uid: "invoice-owner-google-uid",
      timezone: "UTC"
    )
    teammate = User.create!(
      email: "invoice-teammate@example.com",
      name: "Invoice Teammate",
      google_uid: "invoice-teammate-google-uid",
      timezone: "UTC"
    )

    workspace = Workspace.create!(name: "Invoice Workspace", owner: owner)
    Membership.create!(workspace: workspace, user: owner, role: "owner")
    Membership.create!(workspace: workspace, user: teammate, role: "member")

    client = Client.create!(workspace: workspace, name: "Acme Corp")
    setting = InvoiceSetting.create!(workspace: workspace, sender_name: "Owner", notes: "Net 30")
    project = Project.create!(
      workspace: workspace,
      client: client,
      name: "Website Refresh",
      color: "#458588"
    )

    owner_entry = TimeEntry.create!(
      user: owner,
      workspace: workspace,
      project: project,
      description: "Owner work",
      start_at: Time.zone.parse("2026-03-01 09:00:00"),
      end_at: Time.zone.parse("2026-03-01 10:00:00"),
      billable: true
    )
    teammate_entry = TimeEntry.create!(
      user: teammate,
      workspace: workspace,
      project: project,
      description: "Teammate work",
      start_at: Time.zone.parse("2026-03-01 11:00:00"),
      end_at: Time.zone.parse("2026-03-01 12:00:00"),
      billable: true
    )

    invoice = Invoice.generate_from_time_entries(
      workspace,
      client,
      Date.new(2026, 3, 1),
      Date.new(2026, 3, 1),
      10_000,
      owner
    )

    assert_equal 1, invoice.invoice_lines.count
    assert_equal [ owner_entry.id ], invoice.invoice_lines.pluck(:time_entry_id)
    assert_equal 10_000, invoice.total_cents
    assert_empty teammate_entry.reload.invoice_lines

    setting.update!(notes: "Net 60")
    assert_equal "Net 30", invoice.reload.notes
  end

  test "generate_from_time_entries without a period bills every unbilled entry and spans their dates" do
    user = User.create!(
      email: "all-entries@example.com",
      name: "All Entries",
      google_uid: "all-entries-google-uid",
      timezone: "UTC"
    )
    workspace = Workspace.create!(name: "All Entries Workspace", owner: user)
    Membership.create!(workspace: workspace, user: user, role: "owner")
    client = Client.create!(workspace: workspace, name: "Initech")
    other_client = Client.create!(workspace: workspace, name: "Umbrella")
    project = Project.create!(workspace: workspace, client: client, name: "TPS", color: "#458588")
    other_project = Project.create!(workspace: workspace, client: other_client, name: "Hive", color: "#458588")

    entry = ->(project, start, hours) {
      TimeEntry.create!(
        user: user, workspace: workspace, project: project, description: "Work",
        start_at: Time.zone.parse(start), end_at: Time.zone.parse(start) + hours.hours, billable: true
      )
    }
    old_entry = entry.(project, "2025-07-14 09:00:00", 2)
    recent_entry = entry.(project, "2026-02-03 09:00:00", 1)
    entry.(other_project, "2026-02-04 09:00:00", 1)

    invoice = Invoice.generate_from_time_entries(workspace, client, nil, nil, 10_000, user)

    assert_equal [ old_entry.id, recent_entry.id ].sort, invoice.invoice_lines.pluck(:time_entry_id).sort
    assert_equal Date.new(2025, 7, 14), invoice.period_start
    assert_equal Date.new(2026, 2, 3), invoice.period_end
    assert_equal 30_000, invoice.total_cents
    assert_nil Invoice.generate_from_time_entries(workspace, client, nil, nil, 10_000, user)
  end

  test "generate_from_time_entries prices each line from its stored two-decimal hours" do
    workspace = workspaces(:one)
    project = Project.create!(workspace: workspace, client: clients(:one), name: "Rounding", color: "#458588")
    start = Time.zone.parse("2026-08-01 09:00")
    TimeEntry.create!(user: users(:one), workspace: workspace, project: project, description: "Call",
      start_at: start, end_at: start + 25.minutes, billable: true)

    invoice = Invoice.generate_from_time_entries(workspace, clients(:one), Date.new(2026, 8, 1), Date.new(2026, 8, 1), 15_000, users(:one))
    line = invoice.invoice_lines.sole

    assert_equal [ BigDecimal("0.42"), 6_300 ], [ line.qty_hours, line.amount_cents ]
    assert_equal 6_300, invoice.reload.total_cents

    assert invoice.update_line(line, description: "Kickoff call")
    assert_equal [ "Kickoff call", 6_300 ], [ line.reload.description, line.amount_cents ]
  end

  test "generate_from_time_entries copies each entry into a validated line, or creates nothing" do
    workspace = workspaces(:one)
    project = Project.create!(workspace: workspace, client: clients(:one), name: "Line Copy", color: "#458588")
    entries = [ 90, 45 ].each_with_index.map do |minutes, i|
      start = Time.zone.parse("2026-08-0#{i + 1} 09:00")
      TimeEntry.create!(user: users(:one), workspace: workspace, project: project, description: "Task #{i}",
        start_at: start, end_at: start + minutes.minutes, billable: true)
    end

    invoice = Invoice.generate_from_time_entries(workspace, clients(:one), Date.new(2026, 8, 1), Date.new(2026, 8, 2), 10_000, users(:one))

    assert_equal 2, invoice.invoice_lines.size
    lines = invoice.invoice_lines.order(:time_entry_id).map { |line| line.slice(:time_entry_id, :description, :qty_hours, :rate_cents, :amount_cents).symbolize_keys }
    assert_equal [
      { time_entry_id: entries[0].id, description: "Task 0", qty_hours: 1.5, rate_cents: 10_000, amount_cents: 15_000 },
      { time_entry_id: entries[1].id, description: "Task 1", qty_hours: 0.75, rate_cents: 10_000, amount_cents: 7_500 }
    ], lines
    assert_equal 22_500, invoice.reload.total_cents
    assert invoice.invoice_lines.all? { |line| line.created_at.present? && line.updated_at.present? }

    start = Time.zone.parse("2026-08-03 09:00")
    TimeEntry.create!(user: users(:one), workspace: workspace, project: project, description: "Fine", start_at: start, end_at: start + 1.hour, billable: true)
    TimeEntry.create!(user: users(:one), workspace: workspace, project: project, start_at: start + 2.hours, billable: true).update_columns(end_at: start + 3.hours, duration_seconds: 3600)

    assert_no_difference -> { Invoice.count } do
      assert_no_difference -> { InvoiceLine.count } do
        assert_raises(ActiveRecord::RecordInvalid) do
          Invoice.generate_from_time_entries(workspace, clients(:one), Date.new(2026, 8, 3), Date.new(2026, 8, 3), 10_000, users(:one))
        end
      end
    end
  end

  test "issuing a draft sets the issue date to the day it is issued" do
    invoice = invoices(:one)

    travel_to Date.new(2026, 4, 10) do
      invoice.update!(status: Invoice::STATUS_ISSUED)
    end
    assert_equal Date.new(2026, 4, 10), invoice.issued_on

    travel_to Date.new(2026, 5, 1) do
      invoice.update!(status: Invoice::STATUS_PAID)
      invoice.update!(status: Invoice::STATUS_ISSUED)
    end
    assert_equal Date.new(2026, 4, 10), invoice.reload.issued_on

    travel_to Date.new(2026, 6, 3) do
      invoice.update!(status: Invoice::STATUS_DRAFT)
      invoice.update!(status: Invoice::STATUS_ISSUED)
    end
    assert_equal Date.new(2026, 6, 3), invoice.reload.issued_on
  end

  test "a paid invoice goes back to draft only through issued" do
    invoice = invoices(:one)
    invoice.update!(status: Invoice::STATUS_PAID)

    assert_not invoice.update(status: Invoice::STATUS_DRAFT)
    assert_equal Invoice::STATUS_PAID, invoice.reload.status

    invoice.update!(status: Invoice::STATUS_ISSUED)
    invoice.update!(status: Invoice::STATUS_DRAFT)
    assert_equal Invoice::STATUS_DRAFT, invoice.reload.status
  end

  test "reverting to draft makes the lines editable again" do
    invoice = invoices(:one)
    line = invoice.invoice_lines.create!(description: "Work", qty_hours: 1, rate_cents: 100, amount_cents: 100, time_entry: time_entries(:one))
    invoice.update!(status: Invoice::STATUS_ISSUED)

    assert_not invoice.update_line(line, description: "Changed")

    invoice.update!(status: Invoice::STATUS_DRAFT)
    assert invoice.update_line(line, description: "Changed")
    assert_equal "Changed", line.reload.description
  end
end
