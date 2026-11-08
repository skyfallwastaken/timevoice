# frozen_string_literal: true

module Api
  module V1
    class InvoicesController < BaseController
      before_action :require_workspace!
      before_action :set_invoice, only: [ :show, :update, :destroy ]
      before_action -> { require_scope! :invoices }, only: [ :create, :update, :destroy ]

      def index
        invoices = current_workspace.invoices
          .includes(:client)
          .order(created_at: :desc)
        line_counts = current_workspace.invoices.joins(:invoice_lines).group(:id).count

        render json: invoices.map { |invoice| serialize_invoice(invoice, line_count: line_counts.fetch(invoice.id, 0)) }
      end

      def show
        render json: serialize_invoice(@invoice, include_lines: true)
      end

      def create
        authorize Invoice.new(workspace: current_workspace)

        attrs = api_params(:invoice, :client_id, :period_start, :period_end, :rate_cents)
        client = find_referenced!(current_workspace.clients, :client_id, attrs[:client_id])

        invoice = Invoice.generate_from_time_entries(
          current_workspace,
          client,
          parse_date!(:period_start, attrs[:period_start]),
          parse_date!(:period_end, attrs[:period_end]),
          parse_rate!(attrs[:rate_cents]),
          current_user
        )

        if invoice.nil?
          render json: { error: "unprocessable_entity", message: "No unbilled entries found for this client in the selected date range" }, status: :unprocessable_entity
          return
        end

        render json: serialize_invoice(invoice, include_lines: true), status: :created
      end

      def update
        authorize @invoice

        attrs = api_params(:invoice, :status)
        raise InvalidParameter, "status is required" unless attrs.key?(:status)

        if @invoice.update(attrs)
          render json: serialize_invoice(@invoice, include_lines: true)
        else
          render_validation_error(@invoice)
        end
      end

      def destroy
        authorize @invoice

        if @invoice.destroy
          head :no_content
        else
          render_validation_error(@invoice)
        end
      end

      private

      def set_invoice
        @invoice = current_workspace.invoices
          .includes(:client, :invoice_lines)
          .find_by_hashid!(params[:id])
      end

      def parse_date!(field, value)
        raise ArgumentError unless value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Date.iso8601(value.to_s)
      rescue ArgumentError
        raise InvalidParameter, "#{field} must be a valid date (YYYY-MM-DD)"
      end

      def parse_rate!(value)
        return current_workspace.invoice_setting&.billable_rate_cents || 0 if value.nil?

        rate = Integer(value.to_s, 10, exception: false)
        raise InvalidParameter, "rate_cents must be an integer from 0 to #{Invoice::MAX_RATE_CENTS}" unless rate&.between?(0, Invoice::MAX_RATE_CENTS)

        rate
      end

      def serialize_invoice(invoice, include_lines: false, line_count: invoice.invoice_lines.load.size)
        client = invoice.client
        json = {
          id: invoice.hashid,
          number: invoice.invoice_number,
          status: invoice.status,
          total_cents: invoice.total_cents,
          total_amount: invoice.formatted_total,
          period_start: invoice.period_start,
          period_end: invoice.period_end,
          issued_on: invoice.issued_on,
          notes: invoice.notes,
          line_count: line_count,
          client: { id: Client.encode_id(client.id), name: client.name, email: client.email, billing_address: client.billing_address }
        }

        if include_lines
          json[:invoice_lines] = invoice.invoice_lines.map do |line|
            {
              description: line.description,
              qty_hours: line.qty_hours&.to_f,
              rate_cents: line.rate_cents,
              amount_cents: line.amount_cents,
              rate: line.formatted_rate,
              amount: line.formatted_amount
            }
          end
        end

        json
      end
    end
  end
end
