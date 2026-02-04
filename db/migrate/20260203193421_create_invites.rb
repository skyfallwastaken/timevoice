class CreateInvites < ActiveRecord::Migration[8.2]
  def change
    create_table :invites do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.references :workspace, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.string :role, null: false, default: "member"
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :invites, :email
    add_index :invites, :token, unique: true
    add_index :invites, [ :workspace_id, :email ], unique: true, where: "status = 'pending'"
  end
end
