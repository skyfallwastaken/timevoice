class InvoicesController < ApplicationController
  def index
    @invoices = current_workspace.invoices
      .includes(:client, :invoice_lines)
      .order(created_at: :desc)
      .limit(20)

    @clients = current_workspace.clients.order(:name)

    # Get unbilled entries (billable but not yet invoiced)
    @unbilled_entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
      .where(billable: true)
      .left_outer_joins(:invoice_lines)
      .where(invoice_lines: { id: nil })
      .includes(:project, :tags)
      .order(start_at: :desc)

    @invoice_settings = current_workspace.invoice_setting || InvoiceSetting.new(
      billable_rate_cents: 0,
      sender_name: current_user.name
    )

    render inertia: "Invoices/Index", props: {
      invoices: @invoices.map { |invoice|
        invoice.as_json(
          only: [ :id, :status, :total_cents, :period_start, :period_end, :issued_on ],
          include: {
            client: { only: [ :id, :name ] },
            invoice_lines: { only: [ :id, :description, :qty_hours, :amount_cents ] }
          }
        ).merge(
          total_amount: invoice.formatted_total,
          line_count: invoice.invoice_lines.count
        )
      },
      clients: @clients.as_json(only: [ :id, :name, :billing_address ]),
      unbilledEntries: @unbilled_entries.map { |entry|
        entry.as_json(
          only: [ :id, :description, :duration_seconds, :billable, :start_at ],
          include: {
            project: { only: [ :id, :name ] },
            tags: { only: [ :id, :name ] }
          }
        ).merge(
          formattedDuration: entry.formatted_duration,
          hours: (entry.duration_seconds || 0) / 3600.0
        )
      },
      invoiceSettings: {
        billable_rate_cents: @invoice_settings.billable_rate_cents,
        sender_name: @invoice_settings.sender_name,
        sender_address: @invoice_settings.sender_address
      }
    }
  end

  def show
    @invoice = current_workspace.invoices.find(params[:id])

    render inertia: "Invoices/Show", props: {
      invoice: @invoice.as_json(
        only: [ :id, :status, :total_cents, :period_start, :period_end, :issued_on ],
        include: {
          client: { only: [ :id, :name, :billing_address ] },
          invoice_lines: { only: [ :id, :description, :qty_hours, :rate_cents, :amount_cents ] }
        }
      ).merge(
        total_amount: @invoice.formatted_total,
        lines: @invoice.invoice_lines.map { |line|
          line.as_json(
            only: [ :id, :description, :qty_hours, :rate_cents, :amount_cents ]
          ).merge(
            amount: line.formatted_amount,
            rate: line.formatted_rate
          )
        }
      )
    }
  end

  def create
    client = current_workspace.clients.find(params[:client_id])
    start_date = Date.parse(params[:period_start])
    end_date = Date.parse(params[:period_end])
    rate_cents = params[:rate_cents] || current_workspace.invoice_setting&.billable_rate_cents || 0

    # Get billable entries for the client in the date range
    entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
      .where(billable: true)
      .left_outer_joins(:invoice_lines)
      .where(invoice_lines: { id: nil })
      .joins(:project)
      .where(projects: { client_id: client.id })
      .where(start_at: start_date.beginning_of_day..end_date.end_of_day)

    if entries.empty?
      redirect_to invoices_path, alert: "No unbilled entries found for this client in the selected date range."
      return
    end

    invoice = Invoice.create!(
      workspace: current_workspace,
      client: client,
      period_start: start_date,
      period_end: end_date,
      issued_on: Date.current,
      status: "draft",
      total_cents: 0
    )

    total = 0

    entries.each do |entry|
      hours = (entry.duration_seconds || 0) / 3600.0
      amount = (hours * rate_cents).round

      InvoiceLine.create!(
        invoice: invoice,
        time_entry: entry,
        description: entry.description,
        qty_hours: hours,
        rate_cents: rate_cents,
        amount_cents: amount
      )

      total += amount
    end

    invoice.update!(total_cents: total)

    redirect_to invoices_path, notice: "Invoice ##{invoice.id} created successfully with #{entries.count} line items."
  end

  def update
    @invoice = current_workspace.invoices.find(params[:id])

    if @invoice.update(invoice_params)
      redirect_to invoices_path, notice: "Invoice updated successfully!"
    else
      redirect_to invoices_path, alert: @invoice.errors.full_messages.join(", ")
    end
  end

  def destroy
    @invoice = current_workspace.invoices.find(params[:id])
    @invoice.destroy

    redirect_to invoices_path, notice: "Invoice deleted successfully!"
  end

  private

  def invoice_params
    params.require(:invoice).permit(:status)
  end
end
