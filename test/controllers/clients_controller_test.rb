require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  test "a client with invoices is kept and the user is told why" do
    sign_in_as users(:one)
    client = clients(:one)
    assert client.invoices.exists?

    delete "/#{workspaces(:one).hashid}/clients/#{client.id}"

    assert_redirected_to "/#{workspaces(:one).hashid}/clients"
    assert Client.exists?(client.id)
    assert_match "has invoices", flash[:alert]
  end
end
