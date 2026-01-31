require Rails.root.join("app/services/invoice_pdf").to_s

class InvoicesController < ApplicationController
  before_action :set_invoice, only: [ :show, :update, :destroy, :pdf ]
  before_action :authorize_invoice, only: [ :create, :update, :destroy ]
  before_action :authorize_invoice_show, only: [ :show, :pdf ]

  def index
    @invoices = current_workspace.invoices
      .includes(:client, :invoice_lines)
      .order(created_at: :desc)
      .limit(20)

    @clients = current_workspace.clients.order(:name)

    @unbilled_entries = current_user.time_entries
      .where(workspace: current_workspace)
      .completed
      .where(billable: true)
      .left_outer_joins(:invoice_lines)
      .where(invoice_lines: { id: nil })
      .where(TimeEntry.arel_table[:duration_seconds].gteq(36))
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
          methods: [ :hashid ],
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
             project: { only: [ :id, :name, :color ] },
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
    render inertia: "Invoices/Show", props: {
      invoice: @invoice.as_json(
        only: [ :id, :status, :total_cents, :period_start, :period_end, :issued_on ],
        methods: [ :hashid ],
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
    attrs = invoice_create_params

    if attrs[:client_id].blank?
      redirect_to invoices_path, alert: "Please select a client."
      return
    end

    client = current_workspace.clients.find(attrs[:client_id])

    if attrs[:period_start].blank? || attrs[:period_end].blank?
      redirect_to invoices_path, alert: "Please select an invoice period start and end date."
      return
    end

    start_date = Date.parse(attrs[:period_start])
    end_date = Date.parse(attrs[:period_end])
    rate_cents = attrs[:rate_cents].presence || current_workspace.invoice_setting&.billable_rate_cents || 0

    invoice = Invoice.generate_from_time_entries(
      current_workspace,
      client,
      start_date,
      end_date,
      rate_cents,
      current_user
    )

    if invoice.nil?
      redirect_to invoices_path, alert: "No unbilled entries found for this client in the selected date range."
      return
    end

    redirect_to invoices_path, notice: "Invoice ##{invoice.id} created successfully with #{invoice.invoice_lines.count} line items."
  rescue ArgumentError
    redirect_to invoices_path, alert: "Invalid invoice period dates."
  rescue ActiveRecord::RecordNotFound
    redirect_to invoices_path, alert: "Client not found."
  end

  def update
    if params.dig(:invoice, :status) == "issued" && @invoice.issued_on.nil?
      @invoice.issued_on = Date.current
    end

    if @invoice.update(invoice_params)
      redirect_to invoices_path, notice: "Invoice updated successfully!"
    else
      redirect_to invoices_path, alert: @invoice.errors.full_messages.join(", ")
    end
  end

  def destroy
    @invoice.destroy

    redirect_to invoices_path, notice: "Invoice deleted successfully!"
  end

  def pdf
    invoice_setting = current_workspace.invoice_setting

    pdf = ::InvoicePdf.new(@invoice, invoice_setting).generate

    client_name = @invoice.client.name
    date_range = "#{@invoice.period_start.strftime('%b %d, %Y')} - #{@invoice.period_end.strftime('%b %d, %Y')}"
    filename = "Invoice to #{client_name} - #{date_range}.pdf"

    send_data pdf,
      filename: filename,
      type: "application/pdf",
      disposition: "inline"
  end

  private

  def set_invoice
    @invoice = current_workspace.invoices
      .includes(:client, :invoice_lines)
      .find_by_hashid!(params[:id])
  end

  def authorize_invoice
    authorize(@invoice || Invoice.new(workspace: current_workspace))
  end

  def authorize_invoice_show
    authorize(@invoice, :show?)
  end

  def invoice_create_params
    optional_params(:invoice, :client_id, :period_start, :period_end, :rate_cents)
  end

  def invoice_params
    params.require(:invoice).permit(:status)
  end
end
