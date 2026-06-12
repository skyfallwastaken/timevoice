# frozen_string_literal: true

module Api
  module V1
    class ClientsController < BaseController
      before_action :require_workspace!
      before_action :set_client, only: [ :show, :update, :destroy ]

      def index
        clients = current_workspace.clients.order(:name)

        render json: clients.map { |client| serialize_client(client) }
      end

      def show
        render json: serialize_client(@client)
      end

      def create
        require_scope!(:clients)
        return if performed?

        client = current_workspace.clients.build(client_attrs)

        if client.save
          render json: serialize_client(client), status: :created
        else
          render json: { error: "unprocessable_entity", message: client.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:clients)
        return if performed?

        if @client.update(client_attrs)
          render json: serialize_client(@client)
        else
          render json: { error: "unprocessable_entity", message: @client.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        require_scope!(:clients)
        return if performed?

        @client.destroy
        head :no_content
      end

      private

      def set_client
        client_id = Client.decode_id(params[:id])
        @client = current_workspace.clients.find_by!(id: client_id)
      end

      def client_attrs
        api_params(:client, :name, :billing_address)
      end

      def serialize_client(client)
        { id: Client.encode_id(client.id), name: client.name, billing_address: client.billing_address }
      end
    end
  end
end
