require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @path = "/#{workspaces(:one).hashid}/invoices/#{invoices(:one).hashid}"
  end

  test "an issued invoice is kept, so its entries can't be billed again" do
    invoices(:one).update!(status: "issued")

    delete @path

    assert Invoice.exists?(invoices(:one).id)
    assert_equal "Only draft invoices can be deleted", flash[:alert]
  end

  test "a draft invoice can be deleted" do
    delete @path

    assert_redirected_to "/#{workspaces(:one).hashid}/invoices"
    assert_not Invoice.exists?(invoices(:one).id)
  end
end
