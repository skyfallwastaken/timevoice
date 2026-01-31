Rails.application.routes.draw do
  # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  # Authentication
  get "/signin", to: "sessions#new", as: :signin
  delete "/signout", to: "sessions#destroy", as: :signout
  get "/auth/google_oauth2/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  # Workspace-scoped resources (URLs like /:workspace_id/projects)
  scope "/:workspace_id", constraints: { workspace_id: /[a-zA-Z0-9]+/ } do
    get "/timer", to: "dashboard#index"
    get "/calendar", to: "dashboard#calendar"
    get "/reports", to: "reports#index"
    get "/invoices", to: "invoices#index"
    get "/settings", to: "settings#workspace"
    delete "/settings", to: "settings#destroy_workspace"
    get "/settings/billing", to: "settings#billing"
    patch "/settings/billing", to: "settings#update_billing"

    resources :time_entries, only: [ :create, :update, :destroy ] do
      member do
        patch :stop
        put :stop
      end
    end

    resources :projects, only: [ :index, :create, :update, :destroy ]
    resources :clients, only: [ :index, :create, :update, :destroy ]
    resources :tags, only: [ :index, :create, :update, :destroy ]
    resources :memberships, only: [ :create, :destroy ]
    resources :invoices, only: [ :index, :show, :create, :update, :destroy ] do
      member do
        get :pdf
      end
    end
  end

  # Workspaces
  resources :workspaces, only: [ :create ]
  patch "/workspaces/switch", to: "workspaces#switch", as: :switch_workspace

  # Root route - redirects to first workspace
  root "dashboard#index"
  get "/:workspace_id", to: "dashboard#index", constraints: { workspace_id: /[a-zA-Z0-9]+/ }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
