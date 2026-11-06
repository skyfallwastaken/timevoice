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

  test "an unknown theme is rejected" do
    patch "/#{@workspace.hashid}/settings/themes", params: { theme: "neon" }

    assert_equal "daydream-dark", @user.reload.theme
    assert_equal "That theme isn't available.", flash[:alert]
  end
end
