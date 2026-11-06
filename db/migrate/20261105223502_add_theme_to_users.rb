class AddThemeToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :theme, :string, default: "daydream-dark", null: false
  end
end
