class InvoiceLinesController < ApplicationController
  before_action :set_invoice_line

  def update
    if @invoice.update_line(@line, line_params)
      redirect_to invoice_path(current_workspace.hashid, @invoice.hashid), notice: "Line updated."
    else
      redirect_to invoice_path(current_workspace.hashid, @invoice.hashid), alert: @line.errors.full_messages.to_sentence, inertia: { errors: @line.errors }
    end
  end

  def destroy
    if @invoice.remove_line(@line)
      unbilled = @line.time_entry_id && TimeEntry.unbilled.exists?(@line.time_entry_id)
      redirect_to invoice_path(current_workspace.hashid, @invoice.hashid), notice: unbilled ? "Line removed. Its time entry is unbilled again." : "Line removed."
    else
      redirect_to invoice_path(current_workspace.hashid, @invoice.hashid), alert: @line.errors.full_messages.to_sentence
    end
  end

  private

  def set_invoice_line
    @invoice = current_workspace.invoices.find_by_hashid!(params[:invoice_id])
    authorize @invoice, :update?
    @line = @invoice.invoice_lines.find(params[:id])
  end

  def line_params
    params.require(:line).permit(:description, :qty_hours, :rate_cents)
  end
end
