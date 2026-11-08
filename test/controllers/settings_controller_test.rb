require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in_as @user
  end

  test "pages render in Daydream Dark until the user picks a theme" do
    get "/#{@workspace.hashid}/settings/themes"

    assert_select "html[data-theme=?][data-mode=?]", "daydream-dark", "dark"
    assert_equal "daydream-dark", inertia_props["currentTheme"]
  end

  test "a chosen theme is saved and rendered on later pages" do
    patch "/#{@workspace.hashid}/settings/themes", params: { theme: "catppuccin-latte" }
    assert_equal "catppuccin-latte", @user.reload.theme

    get "/#{@workspace.hashid}/timer"
    assert_select "html[data-theme=?][data-mode=?]", "catppuccin-latte", "light"
  end

  test "billing notes are saved, and rejected past the length limit" do
    patch "/#{@workspace.hashid}/settings/billing", params: { setting: { notes: "**Net 30**" } }
    assert_equal "**Net 30**", @workspace.invoice_setting.reload.notes

    patch "/#{@workspace.hashid}/settings/billing", params: { setting: { notes: "a" * 2_001 } }
    assert_equal "**Net 30**", @workspace.invoice_setting.reload.notes
    assert_match "Notes is too long", flash[:alert]
  end

  test "an unknown theme is rejected" do
    patch "/#{@workspace.hashid}/settings/themes", params: { theme: "neon" }

    assert_equal "daydream-dark", @user.reload.theme
    assert_equal "That theme isn't available.", flash[:alert]
  end

  test "deleting a workspace requires its exact name" do
    side = Workspace.create!(name: "Side Project", owner: @user)
    side.memberships.create!(user: @user, role: :owner)

    delete "/#{side.hashid}/settings/workspace"
    assert Workspace.exists?(side.id)

    delete "/#{side.hashid}/settings/workspace", params: { confirm_name: "side project" }
    assert Workspace.exists?(side.id)
    assert_equal "Type the workspace name to confirm deleting it.", flash[:alert]

    delete "/#{side.hashid}/settings/workspace", params: { confirm_name: "Side Project" }
    assert_not Workspace.exists?(side.id)
  end
end
