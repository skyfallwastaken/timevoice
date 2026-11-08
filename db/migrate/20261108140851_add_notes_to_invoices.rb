class AddNotesToInvoices < ActiveRecord::Migration[8.2]
  def change
    add_column :invoices, :notes, :text
  end
end
