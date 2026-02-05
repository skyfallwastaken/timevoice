# frozen_string_literal: true

module Api
  module V1
    class InvoicesController < BaseController
      before_action :require_workspace!
      before_action :set_invoice, only: [:show, :update, :destroy]
      before_action -> { require_scope! :invoices }, only: [:create, :update, :destroy]

      def index
        invoices = current_workspace.invoices
          .includes(:client, :invoice_lines)
          .order(created_at: :desc)

        render json: {
          invoices: invoices.map { |invoice| invoice_json(invoice) }
        }
      end

      def show
        render json: {
          invoice: invoice_json(@invoice, include_lines: true)
        }
      end

      def create
        authorize Invoice.new(workspace: current_workspace)

        client = current_workspace.clients.find(invoice_params[:client_id])

        invoice = Invoice.generate_from_time_entries(
          current_workspace,
          client,
          Date.parse(invoice_params[:period_start]),
          Date.parse(invoice_params[:period_end]),
          invoice_params[:rate_cents].to_i
        )

        if invoice.nil?
          render json: { error: "No unbilled entries found for this client in the selected date range" }, status: :unprocessable_entity
          return
        end

        render json: { invoice: invoice_json(invoice, include_lines: true) }, status: :created
      end

      def update
        authorize @invoice

        if params.dig(:invoice, :status) == "issued" && @invoice.issued_on.nil?
          @invoice.issued_on = Date.current
        end

        if @invoice.update(update_params)
          render json: { invoice: invoice_json(@invoice, include_lines: true) }
        else
          render json: { error: @invoice.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @invoice
        @invoice.destroy
        head :no_content
      end

      private

      def set_invoice
        @invoice = current_workspace.invoices
          .includes(:client, :invoice_lines)
          .find_by_hashid!(params[:id])
      end

      def invoice_params
        params.require(:invoice).permit(:client_id, :period_start, :period_end, :rate_cents)
      end

      def update_params
        params.require(:invoice).permit(:status)
      end

      def invoice_json(invoice, include_lines: false)
        json = invoice.as_json(
          only: [:id, :status, :total_cents, :period_start, :period_end, :issued_on],
          methods: [:hashid],
          include: {
            client: { only: [:id, :name, :billing_address] }
          }
        ).merge(
          total_amount: invoice.formatted_total,
          line_count: invoice.invoice_lines.size
        )

        if include_lines
          json[:invoice_lines] = invoice.invoice_lines.map do |line|
            line.as_json(only: [:id, :description, :qty_hours, :rate_cents, :amount_cents]).merge(
              amount: line.formatted_amount,
              rate: line.formatted_rate
            )
          end
        end

        json
      end
    end
  end
end
