# frozen_string_literal: true

class ChangeOauthApplicationsFromUserToWorkspace < ActiveRecord::Migration[8.2]
  def change
    remove_foreign_key :oauth_applications, :users
    remove_reference :oauth_applications, :user, index: true

    add_reference :oauth_applications, :workspace, null: false, foreign_key: true
  end
end
