class AddInvoiceNumberToInvoices < ActiveRecord::Migration[8.2]
  def change
    add_column :invoices, :invoice_number, :integer
    add_index :invoices, [ :workspace_id, :invoice_number ], unique: true

    # Populate existing invoices with sequential numbers per workspace
    reversible do |dir|
      dir.up do
        Workspace.find_each do |workspace|
          workspace.invoices.order(:created_at).each_with_index do |invoice, index|
            invoice.update_column(:invoice_number, index + 1)
          end
        end
      end
    end

    # Make invoice_number non-nullable after populating
    change_column_null :invoices, :invoice_number, false
  end
end
