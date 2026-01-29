class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true
      t.text :description
      t.datetime :start_at, null: false
      t.datetime :end_at
      t.integer :duration_seconds
      t.boolean :billable, default: false

      t.timestamps
    end

    add_index :time_entries, :start_at
    add_index :time_entries, :billable
    add_index :time_entries, [ :user_id, :workspace_id ]
  end
end
