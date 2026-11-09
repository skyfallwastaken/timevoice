class AddUse24HourClockToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :use_24_hour_clock, :boolean, default: false, null: false
  end
end
