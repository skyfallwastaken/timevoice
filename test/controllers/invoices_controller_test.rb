require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @path = "/#{workspaces(:one).hashid}/invoices/#{invoices(:one).hashid}"
  end

  test "an issued invoice is kept, so its entries can't be billed again" do
    invoices(:one).update!(status: "issued")

    delete @path

    assert_redirected_to "/#{workspaces(:one).hashid}/invoices"
    assert Invoice.exists?(invoices(:one).id)
    assert_equal "Only draft invoices can be deleted", flash[:alert]
  end

  test "a draft invoice can be deleted" do
    delete @path

    assert_redirected_to "/#{workspaces(:one).hashid}/invoices"
    assert_not Invoice.exists?(invoices(:one).id)
  end

  test "creating an invoice opens the new invoice" do
    workspace = workspaces(:one)
    TimeEntry.create!(user: users(:one), workspace: workspace, project: projects(:one), description: "Work", billable: true, start_at: 1.hour.ago, end_at: Time.current, duration_seconds: 3600)

    assert_difference -> { workspace.invoices.count } do
      post "/#{workspace.hashid}/invoices", params: { invoice: { client_id: clients(:one).id, all_entries: true, rate_cents: 10_000 } }
    end

    invoice = workspace.invoices.order(:id).last
    assert_redirected_to "/#{workspace.hashid}/invoices/#{invoice.hashid}"
    assert_match "Invoice ##{invoice.invoice_number} created", flash[:notice]
  end
end
