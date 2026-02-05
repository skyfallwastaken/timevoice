# frozen_string_literal: true

class CreateDoorkeeperTables < ActiveRecord::Migration[8.2]
  def change
    create_table :oauth_applications do |t|
      t.string  :name,    null: false
      t.string  :uid,     null: false
      t.string  :secret

      t.text    :redirect_uri, null: false
      t.string  :scopes,       null: false, default: ''
      t.boolean :confidential, null: false, default: false
      t.string  :trust_level,  null: false, default: "community"
      t.references :user, null: false, foreign_key: true
      t.timestamps             null: false
    end

    add_index :oauth_applications, :uid, unique: true
    add_index :oauth_applications, :trust_level

    create_table :oauth_access_grants do |t|
      t.references :resource_owner,  null: false
      t.references :application,     null: false
      t.string   :token,             null: false
      t.integer  :expires_in,        null: false
      t.text     :redirect_uri,      null: false
      t.string   :scopes,            null: false, default: ''
      t.datetime :created_at,        null: false
      t.datetime :revoked_at
      t.string   :code_challenge
      t.string   :code_challenge_method
    end

    add_index :oauth_access_grants, :token, unique: true
    add_foreign_key(
      :oauth_access_grants,
      :oauth_applications,
      column: :application_id
    )

    create_table :oauth_access_tokens do |t|
      t.references :resource_owner, index: true
      t.references :application,    null: false

      t.string :token, null: false

      t.string   :refresh_token
      t.integer  :expires_in
      t.string   :scopes
      t.datetime :created_at, null: false
      t.datetime :revoked_at

      t.string   :previous_refresh_token, null: false, default: ""
    end

    add_index :oauth_access_tokens, :token, unique: true

    if ActiveRecord::Base.connection.adapter_name == "SQLServer"
      execute <<~SQL.squish
        CREATE UNIQUE NONCLUSTERED INDEX index_oauth_access_tokens_on_refresh_token ON oauth_access_tokens(refresh_token)
        WHERE refresh_token IS NOT NULL
      SQL
    else
      add_index :oauth_access_tokens, :refresh_token, unique: true
    end

    add_foreign_key(
      :oauth_access_tokens,
      :oauth_applications,
      column: :application_id
    )

    add_foreign_key :oauth_access_grants, :users, column: :resource_owner_id
    add_foreign_key :oauth_access_tokens, :users, column: :resource_owner_id
  end
end
