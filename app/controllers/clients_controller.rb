class ClientsController < ApplicationController
  def index
    @clients = current_workspace.clients.order(:name)

    render inertia: "Clients/Index", props: {
      clients: @clients.as_json(only: [ :id, :name, :billing_address ])
    }
  end

  def create
    @client = current_workspace.clients.build(client_params)

    if @client.save
      redirect_to clients_path, notice: "Client created successfully!"
    else
      redirect_to clients_path, alert: @client.errors.full_messages.join(", ")
    end
  end

  def update
    @client = current_workspace.clients.find(params[:id])

    if @client.update(client_params)
      redirect_to clients_path, notice: "Client updated successfully!"
    else
      redirect_to clients_path, alert: @client.errors.full_messages.join(", ")
    end
  end

  def destroy
    @client = current_workspace.clients.find(params[:id])
    @client.destroy

    redirect_to clients_path, notice: "Client deleted successfully!"
  end

  private

  def client_params
    params.require(:client).permit(:name, :billing_address)
  end
end
