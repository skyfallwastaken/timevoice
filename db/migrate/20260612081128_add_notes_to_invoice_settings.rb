class AddNotesToInvoiceSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :invoice_settings, :notes, :text
  end
end
