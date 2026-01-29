class CreateInvoiceLines < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_lines do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :time_entry, null: true, foreign_key: true
      t.string :description, null: false
      t.decimal :qty_hours, precision: 5, scale: 2
      t.integer :rate_cents
      t.integer :amount_cents, null: false

      t.timestamps
    end
  end
end
