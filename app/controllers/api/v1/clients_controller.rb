# frozen_string_literal: true

module Api
  module V1
    class ClientsController < BaseController
      before_action :require_workspace!
      before_action :set_client, only: [ :show, :update, :destroy ]
      before_action -> { require_scope! :clients }, only: [ :create, :update, :destroy ]

      def index
        clients = current_workspace.clients.order(:name)

        render json: clients.map { |client| serialize_client(client) }
      end

      def show
        render json: serialize_client(@client)
      end

      def create
        client = current_workspace.clients.build(client_attrs)

        if client.save
          render json: serialize_client(client), status: :created
        else
          render_validation_error(client)
        end
      end

      def update
        if @client.update(client_attrs)
          render json: serialize_client(@client)
        else
          render_validation_error(@client)
        end
      end

      def destroy
        if @client.destroy
          head :no_content
        else
          render_validation_error(@client)
        end
      end

      private

      def set_client
        @client = current_workspace.clients.find_by_hashid!(params[:id])
      end

      def client_attrs
        api_params(:client, :name, :billing_address, :email)
      end

      def serialize_client(client)
        { id: Client.encode_id(client.id), name: client.name, email: client.email, billing_address: client.billing_address }
      end
    end
  end
end
