class CreateInvoiceSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_settings do |t|
      t.references :workspace, null: false, foreign_key: true
      t.integer :billable_rate_cents, null: false, default: 0
      t.string :sender_name, null: false
      t.text :sender_address

      t.timestamps
    end
  end
end
