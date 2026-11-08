require "test_helper"

class ApiV1Test < ActionDispatch::IntegrationTest
  setup do
    scopes = "read time_entries projects tags clients invoices"
    app = OauthApplication.create!(name: "Test client", redirect_uri: "https://example.com/callback", workspace: workspaces(:one), scopes: scopes)
    @token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: users(:one).id, scopes: scopes).token
  end

  test "ids returned by the API can be used to build its URLs" do
    workspace_id = api(:get, "/workspaces").first["id"]

    entry = api(:post, "/#{workspace_id}/time_entries", {
      description: "Flat body",
      started_at: "2026-06-12T08:00:00Z",
      ended_at: "2026-06-12T09:15:00Z",
      project_id: Project.encode_id(projects(:one).id),
      tag_ids: [ Tag.encode_id(tags(:one).id) ]
    })
    assert_response :created
    assert_equal 4500, entry["duration_seconds"]
    assert_equal "2026-06-12T08:00:00.000Z", entry["started_at"]
    assert_equal [ tags(:one).name ], entry["tags"].pluck("name")

    assert_equal entry, api(:get, "/#{workspace_id}/time_entries/#{entry["id"]}")

    running = api(:post, "/#{workspace_id}/time_entries/start", { description: "Running" })
    assert_nil running["ended_at"]
    restarted = api(:post, "/#{workspace_id}/time_entries/start", { description: "Running again" })
    assert_equal [ restarted["id"] ], TimeEntry.running.map { |e| TimeEntry.encode_id(e.id) }
    running = restarted
    stopped = api(:patch, "/#{workspace_id}/time_entries/#{running["id"]}/stop")
    assert_response :success
    assert_not_nil stopped["ended_at"]
  end

  test "references to records outside the workspace are rejected with 422" do
    workspace_id = workspaces(:one).hashid

    assert_no_difference -> { TimeEntry.count } do
      api(:post, "/#{workspace_id}/time_entries", { started_at: "2026-06-12T08:00:00Z", project_id: Project.encode_id(projects(:two).id) })
      assert_response :unprocessable_entity

      api(:post, "/#{workspace_id}/time_entries", { started_at: "2026-06-12T08:00:00Z", tag_ids: [ Tag.encode_id(tags(:one).id), Tag.encode_id(tags(:two).id) ] })
      assert_response :unprocessable_entity

      api(:post, "/#{workspace_id}/time_entries", { started_at: "2026-06-12T08:00:00Z", tag_ids: [ "not-a-hashid!" ] })
      assert_response :unprocessable_entity
    end

    entry = time_entries(:one)
    tags_before = entry.tags.to_a
    api(:patch, "/#{workspace_id}/time_entries/#{TimeEntry.encode_id(entry.id)}", { ended_at: "garbage", tag_ids: [] })
    assert_response :unprocessable_entity
    assert_equal entry.end_at, entry.reload.end_at
    assert_equal tags_before, entry.tags.to_a

    assert_no_difference -> { Project.count } do
      api(:post, "/#{workspace_id}/projects", { name: "Foreign client", color: "#458588", client_id: Client.encode_id(clients(:two).id) })
      assert_response :unprocessable_entity
    end
  end

  test "nested and form-encoded bodies are accepted as well as flat JSON" do
    workspace_id = workspaces(:one).hashid

    entry = api(:post, "/#{workspace_id}/time_entries", { time_entry: { description: "Nested", start_at: "2026-06-12T08:00:00Z", end_at: "2026-06-12T08:30:00Z" } })
    assert_response :created
    assert_equal 1800, entry["duration_seconds"]

    post "/api/v1/#{workspace_id}/projects", params: { name: "Form encoded", color: "#458588" }, headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :created
    assert_equal "Form encoded", response.parsed_body["name"]
  end

  test "time entries can be filtered by date and running state" do
    workspace_id = workspaces(:one).hashid
    api(:post, "/#{workspace_id}/time_entries", { description: "Before", started_at: "2026-06-11T23:30:00Z", ended_at: "2026-06-12T00:30:00Z" })
    api(:post, "/#{workspace_id}/time_entries", { description: "Inside", started_at: "2026-06-12T08:00:00Z", ended_at: "2026-06-12T09:00:00Z" })

    entries = api(:get, "/#{workspace_id}/time_entries?start_date=2026-06-12&end_date=2026-06-12")
    assert_equal [ "Inside" ], entries.pluck("description")

    api(:get, "/#{workspace_id}/time_entries?start_date=yesterday")
    assert_response :unprocessable_entity

    api(:post, "/#{workspace_id}/time_entries", { description: "Long running", started_at: "2026-01-01T08:00:00Z" })
    assert_equal [ "Long running" ], api(:get, "/#{workspace_id}/time_entries?running=true").pluck("description")
    stopped = api(:get, "/#{workspace_id}/time_entries?running=false")
    assert_equal 3, stopped.size
    assert stopped.all? { |entry| entry["ended_at"] }
  end

  test "clients store, return, update and clear their email" do
    workspace_id = workspaces(:one).hashid

    client = api(:post, "/#{workspace_id}/clients", { name: "Emailed", email: "ap@acme.test; boss@acme.test" })
    assert_response :created
    assert_equal "ap@acme.test, boss@acme.test", client["email"]
    assert_equal client, api(:get, "/#{workspace_id}/clients/#{client["id"]}")

    api(:patch, "/#{workspace_id}/clients/#{client["id"]}", { email: "new@acme.test" })
    assert_response :success
    assert_equal "new@acme.test", api(:get, "/#{workspace_id}/clients/#{client["id"]}")["email"]

    api(:patch, "/#{workspace_id}/clients/#{client["id"]}", { email: "nope" })
    assert_response :unprocessable_entity
    assert_equal "new@acme.test", Client.find_by_hashid(client["id"]).email

    cleared = api(:patch, "/#{workspace_id}/clients/#{client["id"]}", { email: nil })
    assert_response :success
    assert_nil cleared["email"]
  end

  test "invoices follow the documented contract" do
    workspace_id = workspaces(:one).hashid
    client_id = Client.encode_id(clients(:one).id)
    invoice_settings(:one).update!(notes: "**Net 30**", billable_rate_cents: 9_000)
    TimeEntry.create!(user: users(:one), workspace: workspaces(:one), project: projects(:one), description: "Design",
      start_at: Time.zone.parse("2026-06-12 08:00"), end_at: Time.zone.parse("2026-06-12 09:30"), billable: true)

    invoice = api(:post, "/#{workspace_id}/invoices", { client_id: client_id, period_start: "2026-06-01", period_end: "2026-06-30" })
    assert_response :created
    assert_equal client_id, invoice["client"]["id"]
    assert_equal "**Net 30**", invoice["notes"]
    assert_equal 13_500, invoice["total_cents"]
    assert_equal [ 1.5 ], invoice["invoice_lines"].pluck("qty_hours")

    assert_equal invoice, api(:get, "/#{workspace_id}/invoices/#{invoice["id"]}")
    assert_equal invoice.except("invoice_lines"), api(:get, "/#{workspace_id}/invoices").find { |listed| listed["id"] == invoice["id"] }

    assert_equal "issued", api(:patch, "/#{workspace_id}/invoices/#{invoice["id"]}", { status: "issued" })["status"]

    assert_equal "Only draft invoices can be deleted", api(:delete, "/#{workspace_id}/invoices/#{invoice["id"]}")["message"]
    assert_response :unprocessable_entity
    assert Invoice.exists?(Invoice.decode_id(invoice["id"]))

    api(:delete, "/#{workspace_id}/invoices/#{invoices(:one).hashid}")
    assert_response :no_content
    assert_not Invoice.exists?(invoices(:one).id)
  end

  test "invalid invoice input is rejected with 422" do
    workspace_id = workspaces(:one).hashid
    valid = { client_id: Client.encode_id(clients(:one).id), period_start: "2026-01-01", period_end: "2026-01-31" }

    assert_no_difference -> { Invoice.count } do
      api(:post, "/#{workspace_id}/invoices", valid.merge(client_id: Client.encode_id(clients(:two).id)))
      assert_response :unprocessable_entity

      api(:post, "/#{workspace_id}/invoices", valid.merge(period_start: "January"))
      assert_response :unprocessable_entity

      assert_match "period_end", api(:post, "/#{workspace_id}/invoices", valid.merge(period_end: "20260131"))["message"]

      api(:post, "/#{workspace_id}/invoices", valid.merge(rate_cents: -5))
      assert_response :unprocessable_entity

      assert_match "rate_cents", api(:post, "/#{workspace_id}/invoices", valid.merge(rate_cents: ""))["message"]
    end

    api(:patch, "/#{workspace_id}/invoices/#{invoices(:one).hashid}", { status: "sent" })
    assert_response :unprocessable_entity
    assert_equal "status is required", api(:patch, "/#{workspace_id}/invoices/#{invoices(:one).hashid}", {})["message"]
    assert_equal "draft", invoices(:one).reload.status
  end

  test "a client with invoices is not deleted" do
    api(:delete, "/#{workspaces(:one).hashid}/clients/#{Client.encode_id(clients(:one).id)}")

    assert_response :unprocessable_entity
    assert Client.exists?(clients(:one).id)
  end

  private

  def api(verb, path, body = nil)
    send(verb, "/api/v1#{path}", params: body&.to_json, headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" })
    response.parsed_body
  end
end
