require "test_helper"

class ThemeTest < ActiveSupport::TestCase
  ASSETS = Rails.root.join("app/frontend/assets")

  def palette_tokens
    File.read(ASSETS.join("tailwind.css"))[/@theme \{(.*?)\n\}/m, 1].scan(/--(color-[\w-]+):/).flatten
  end

  def theme_blocks
    File.read(ASSETS.join("themes.css")).scan(/\[data-theme="([\w-]+)"\] \{(.*?)\}/m).to_h do |key, body|
      [ key, body.scan(/--(color-[\w-]+): (#\h{6});/).to_h ]
    end
  end

  def luminance(hex)
    hex.delete("#").scan(/../).map { |c| c.to_i(16) / 255.0 }
      .map { |v| v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
      .zip([ 0.2126, 0.7152, 0.0722 ]).sum { |v, weight| v * weight }
  end

  def contrast(foreground, background)
    lo, hi = [ luminance(foreground), luminance(background) ].minmax
    (hi + 0.05) / (lo + 0.05)
  end

  test "every theme has a complete palette in themes.css" do
    blocks = theme_blocks
    assert_equal Theme.keys.sort, blocks.keys.sort

    blocks.each do |key, vars|
      assert_empty palette_tokens - vars.keys, "#{key} is missing palette colors"
    end
  end

  test "theme text and accents meet contrast targets on page and card backgrounds" do
    theme_blocks.each do |key, vars|
      [ vars["color-bg-primary"], vars["color-bg-secondary"] ].each do |bg|
        assert_operator contrast(vars["color-fg-primary"], bg), :>=, 7, "#{key} fg-primary"
        assert_operator contrast(vars["color-fg-muted"], bg), :>=, 4.5, "#{key} fg-muted"
        assert_operator contrast(vars["color-fg-dim"], bg), :>=, 3, "#{key} fg-dim"
        vars.each do |name, color|
          next unless name.start_with?("color-bright-")
          assert_operator contrast(color, bg), :>=, 4.5, "#{key} #{name}"
        end
      end
    end
  end

  test "unknown theme keys fall back to the default" do
    assert_equal "daydream-dark", Theme.find("nope").key
    assert_equal "light", Theme.find("catppuccin-latte").mode
  end
end
