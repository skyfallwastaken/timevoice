class CreateTimeEntryTags < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entry_tags do |t|
      t.references :time_entry, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :time_entry_tags, [ :time_entry_id, :tag_id ], unique: true
  end
end
