require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "tags are listed case-insensitively, the order the page sorts optimistic rows in" do
    sign_in_as users(:one)
    %w[Research design apple Design].each { |name| workspaces(:one).tags.create!(name: name) }

    get "/#{workspaces(:one).hashid}/tags"

    assert_equal %w[apple Design design MyString Research], inertia_props["tags"].pluck("name")
  end
end
