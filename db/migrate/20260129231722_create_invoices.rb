class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.date :issued_on, null: false
      t.string :status, null: false, default: 'draft'
      t.integer :total_cents, null: false, default: 0

      t.timestamps
    end

    add_index :invoices, :status
    add_index :invoices, [ :workspace_id, :client_id ]
  end
end
