require Rails.root.join("app/services/invoice_pdf").to_s
require "csv"

class InvoicesController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> {
    redirect_to invoices_path, alert: "Too many invoice creation attempts. Please wait a minute."
  }
  rate_limit to: 5, within: 1.minute, name: "send_email", only: :send_email, with: -> {
    redirect_back fallback_location: invoices_path, alert: "Too many email attempts. Please wait a minute."
  }
  verify_turnstile_request only: [ :send_email ]

  before_action :set_invoice, only: [ :show, :update, :destroy, :pdf, :csv, :send_email ]
  before_action :authorize_invoice, only: [ :create, :update, :destroy, :send_email ]
  before_action :authorize_invoice_show, only: [ :show, :pdf, :csv ]

  def index
    @invoices = current_workspace.invoices
      .includes(:client)
      .order(created_at: :desc)
    line_counts = InvoiceLine.where(invoice_id: current_workspace.invoices.select(:id)).group(:invoice_id).count

    @clients = current_workspace.clients.sorted_by_name

    @unbilled_entries = policy_scope(TimeEntry)
      .unbilled
      .includes(project: :client)
      .order(start_at: :desc)

    @invoice_settings = current_workspace.invoice_setting || InvoiceSetting.new(
      billable_rate_cents: 0,
      sender_name: current_user.name
    )

    render inertia: "Invoices/Index", props: {
      invoices: @invoices.map { |invoice|
        invoice.as_json(
          only: [ :id, :invoice_number, :status, :total_cents, :period_start, :period_end, :issued_on ],
          methods: [ :hashid ],
          include: { client: { only: [ :id, :name ] } }
        ).merge(
          total_amount: invoice.formatted_total,
          line_count: line_counts[invoice.id] || 0
        )
      },
      clients: @clients.as_json(only: [ :id, :name, :billing_address ]),
      unbilledEntries: @unbilled_entries.map { |entry|
        entry.as_json(
          only: [ :id, :description, :duration_seconds, :billable, :start_at ],
          include: {
            project: { only: [ :id, :name, :color, :client_id ], include: { client: { only: [ :id, :name ] } } }
          }
        ).merge(hours: entry.invoice_hours)
      },
      invoiceSettings: {
        billable_rate_cents: @invoice_settings.billable_rate_cents,
        sender_name: @invoice_settings.sender_name,
        sender_address: @invoice_settings.sender_address
      }
    }
  end

  def show
    invoice_setting = current_workspace.invoice_setting

    render inertia: "Invoices/Show", props: {
      canEdit: policy(@invoice).update?,
      sender: {
        name: invoice_setting&.sender_name || "Your Company",
        address: invoice_setting&.sender_address
      },
      invoice: @invoice.as_json(
        only: [ :id, :invoice_number, :status, :total_cents, :period_start, :period_end, :issued_on, :notes ],
        methods: [ :hashid ],
        include: {
          client: { only: [ :id, :name, :billing_address, :email ] }
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
      redirect_with_error invoices_path, "Please select a client.", field: :client_id
      return
    end

    client = current_workspace.clients.find(attrs[:client_id])
    all_entries = ActiveModel::Type::Boolean.new.cast(attrs[:all_entries])

    unless all_entries
      if attrs[:period_start].blank? || attrs[:period_end].blank?
        redirect_with_error invoices_path, "Please select an invoice period start and end date.", field: :period_start
        return
      end

      start_date = Date.parse(attrs[:period_start])
      end_date = Date.parse(attrs[:period_end])
    end

    rate_cents = if attrs[:rate_cents].present?
      Integer(attrs[:rate_cents].to_s, 10, exception: false)
    else
      current_workspace.invoice_setting&.billable_rate_cents || 0
    end

    unless rate_cents&.between?(0, Invoice::MAX_RATE_CENTS)
      redirect_with_error invoices_path, "Billable rate must be a valid amount.", field: :rate_cents
      return
    end

    invoice = Invoice.generate_from_time_entries(
      current_workspace,
      client,
      start_date,
      end_date,
      rate_cents,
      current_user
    )

    if invoice.nil?
      redirect_with_error invoices_path, all_entries ? "No unbilled entries found for this client." : "No unbilled entries found for this client in the selected date range."
      return
    end

    redirect_to invoice_path(current_workspace.hashid, invoice.hashid), notice: "Invoice ##{invoice.invoice_number} created successfully with #{invoice.invoice_lines.count} line items."
  rescue ArgumentError
    redirect_with_error invoices_path, "Invalid invoice period dates.", field: :period_start
  rescue ActiveRecord::RecordNotFound
    redirect_with_error invoices_path, "Client not found.", field: :client_id
  end

  def update
    if @invoice.update(invoice_params)
      redirect_back fallback_location: invoices_path, notice: "Invoice updated successfully!"
    else
      redirect_back_with_record_errors @invoice, fallback_location: invoices_path
    end
  end

  def destroy
    if @invoice.destroy
      redirect_to invoices_path, notice: "Invoice ##{@invoice.invoice_number} deleted successfully!"
    else
      redirect_back fallback_location: invoices_path, alert: @invoice.errors.full_messages.join(", ")
    end
  end

  def pdf
    invoice_setting = current_workspace.invoice_setting

    pdf = ::InvoicePdf.new(@invoice, invoice_setting).generate

    send_data pdf,
      filename: @invoice.filename("pdf"),
      type: "application/pdf",
      disposition: "inline"
  end

  def csv
    data = CSV.generate do |csv|
      csv << [ "Description", "Hours", "Amount" ]
      @invoice.invoice_lines.each do |line|
        csv << [ line.description, line.qty_hours, line.formatted_amount ]
      end
    end

    send_data data,
      filename: @invoice.filename("csv"),
      type: "text/csv",
      disposition: "attachment"
  end

  def send_email
    recipients = email_params[:recipients].to_s.split(/[,;\s]+/).map(&:strip).reject(&:blank?)
    cc = email_params[:cc_self] == "true" ? [ current_user.email ] : []
    message = email_params[:message].to_s.strip

    if recipients.empty?
      redirect_with_error invoice_path(current_workspace.hashid, @invoice.hashid), "Please enter at least one recipient email.", field: :recipients
      return
    end

    invalid_emails = recipients.reject { |email| email.match?(URI::MailTo::EMAIL_REGEXP) }
    if invalid_emails.any?
      redirect_with_error invoice_path(current_workspace.hashid, @invoice.hashid), "Invalid email address: #{invalid_emails.first}", field: :recipients
      return
    end

    SendInvoiceEmailJob.perform_later(
      invoice_id: @invoice.id,
      recipients: recipients,
      cc: cc,
      message: message
    )

    redirect_to invoice_path(current_workspace.hashid, @invoice.hashid), notice: "Invoice email queued for delivery to #{recipients.count} #{"recipient".pluralize(recipients.count)}."
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
    optional_params(:invoice, :client_id, :period_start, :period_end, :rate_cents, :all_entries)
  end

  def invoice_params
    params.require(:invoice).permit(:status, :invoice_number)
  end

  def email_params
    params.permit(:recipients, :cc_self, :message)
  end
end
