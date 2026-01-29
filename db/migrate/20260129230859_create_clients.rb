class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.text :billing_address

      t.timestamps
    end

    add_index :clients, [ :workspace_id, :name ], unique: true
  end
end
