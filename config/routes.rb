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

  # Main app routes
  root "dashboard#index"
  get "/calendar", to: "dashboard#calendar"
  get "/entries", to: "time_entries#index"
  get "/reports", to: "reports#index"
  get "/invoices", to: "invoices#index"
  get "/settings/workspace", to: "settings#workspace"
  get "/settings/billing", to: "settings#billing"
  patch "/settings/billing", to: "settings#update_billing"

  # Time entries API
  resources :time_entries, only: [ :create, :update, :destroy ] do
    member do
      patch :stop
      put :stop
    end
  end

  # Projects, Clients, and Tags
  resources :projects, only: [ :index, :create, :update, :destroy ]
  resources :clients, only: [ :index, :create, :update, :destroy ]
  resources :tags, only: [ :index, :create, :update, :destroy ]

  # Invoices
  resources :invoices, only: [ :index, :show, :create, :update, :destroy ]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
