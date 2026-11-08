class AddEmailToClients < ActiveRecord::Migration[8.2]
  def change
    add_column :clients, :email, :string
  end
end
