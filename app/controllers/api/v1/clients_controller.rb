# frozen_string_literal: true

module Api
  module V1
    class ClientsController < BaseController
      before_action :require_workspace!
      before_action :set_client, only: [ :show, :update, :destroy ]

      def index
        clients = current_workspace.clients.order(:name)

        render json: clients.as_json(only: [ :id, :name, :billing_address ])
      end

      def show
        render json: @client.as_json(only: [ :id, :name, :billing_address ])
      end

      def create
        require_scope!(:clients)
        return if performed?

        client = current_workspace.clients.build(client_params)

        if client.save
          render json: client.as_json(only: [ :id, :name, :billing_address ]), status: :created
        else
          render json: { error: "unprocessable_entity", message: client.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        require_scope!(:clients)
        return if performed?

        if @client.update(client_params)
          render json: @client.as_json(only: [ :id, :name, :billing_address ])
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
        @client = current_workspace.clients.find(params[:id])
      end

      def client_params
        params.require(:client).permit(:name, :billing_address)
      end
    end
  end
end
