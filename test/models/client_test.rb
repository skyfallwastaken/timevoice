require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "email accepts several addresses and stores them comma-separated" do
    client = Client.new(workspace: workspaces(:one), name: "Acme", email: " ap@acme.test;  boss@acme.test,,\nops@acme.test ")

    assert client.valid?
    assert_equal "ap@acme.test, boss@acme.test, ops@acme.test", client.email
  end

  test "email is optional but every address must be valid" do
    assert Client.new(workspace: workspaces(:one), name: "No email", email: " ").valid?

    client = Client.new(workspace: workspaces(:one), name: "Acme", email: "ap@acme.test, not-an-email")
    assert_not client.valid?
    assert_includes client.errors[:email].first, "not-an-email"
  end
end
