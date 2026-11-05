require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  test "generate_from_time_entries filters to the provided user" do
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
end
