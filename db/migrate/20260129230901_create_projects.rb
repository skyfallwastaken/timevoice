class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :client, null: true, foreign_key: true
      t.string :name, null: false
      t.string :color, default: "#b16286"
      t.boolean :billable_default, default: false

      t.timestamps
    end

    add_index :projects, [ :workspace_id, :name ], unique: true
    add_index :projects, :color
  end
end
