require "test_helper"

class ApiV1Test < ActionDispatch::IntegrationTest
  setup do
    scopes = "read time_entries projects tags clients"
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
    stopped = api(:patch, "/#{workspace_id}/time_entries/#{running["id"]}/stop")
    assert_response :success
    assert_not_nil stopped["ended_at"]
  end

  test "references to records outside the workspace are rejected with 422" do
    workspace_id = workspaces(:one).hashid

    assert_no_difference -> { TimeEntry.count } do
      api(:post, "/#{workspace_id}/time_entries", { started_at: "2026-06-12T08:00:00Z", project_id: Project.encode_id(projects(:two).id) })
      assert_response :unprocessable_entity

      api(:post, "/#{workspace_id}/time_entries", { started_at: "2026-06-12T08:00:00Z", tag_ids: [ "not-a-hashid!" ] })
      assert_response :unprocessable_entity
    end

    assert_no_difference -> { Project.count } do
      api(:post, "/#{workspace_id}/projects", { name: "Foreign client", color: "#458588", client_id: Client.encode_id(clients(:two).id) })
      assert_response :unprocessable_entity
    end
  end

  test "time entries can be filtered by date" do
    workspace_id = workspaces(:one).hashid
    api(:post, "/#{workspace_id}/time_entries", { description: "Before", started_at: "2026-06-11T23:30:00Z", ended_at: "2026-06-12T00:30:00Z" })
    api(:post, "/#{workspace_id}/time_entries", { description: "Inside", started_at: "2026-06-12T08:00:00Z", ended_at: "2026-06-12T09:00:00Z" })

    entries = api(:get, "/#{workspace_id}/time_entries?start_date=2026-06-12&end_date=2026-06-12")
    assert_equal [ "Inside" ], entries.pluck("description")

    api(:get, "/#{workspace_id}/time_entries?start_date=yesterday")
    assert_response :unprocessable_entity
  end

  private

  def api(verb, path, body = nil)
    send(verb, "/api/v1#{path}", params: body&.to_json, headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" })
    response.parsed_body
  end
end
