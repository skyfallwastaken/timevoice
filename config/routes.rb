Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  namespace :admin do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  constraints(host: "127.0.0.1") do
    get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
  end

  get "/home", to: "marketing#home", as: :marketing_home
  get "/signin", to: "sessions#new", as: :signin
  delete "/signout", to: "sessions#destroy", as: :signout
  get "/auth/google_oauth2/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  get "/invites", to: "invites#index", as: :invites
  get "/invite/:token", to: "invites#show", as: :invite
  post "/invite/:token/accept", to: "invites#accept", as: :accept_invite
  post "/invite/:token/decline", to: "invites#decline", as: :decline_invite

  scope "/:workspace_id", constraints: { workspace_id: /[a-zA-Z0-9]+/ } do
    get "/timer", to: "dashboard#index"
    get "/calendar", to: "dashboard#calendar"
    get "/reports", to: "reports#index"
    get "/invoices", to: "invoices#index"
    get "/settings", to: "settings#workspace"
    get "/settings/workspace", to: "settings#workspace"
    patch "/settings/workspace", to: "settings#update_workspace"
    delete "/settings/workspace", to: "settings#destroy_workspace"
    get "/settings/billing", to: "settings#billing"
    patch "/settings/billing", to: "settings#update_billing"

    resources :time_entries, only: [ :create, :update, :destroy ] do
      member do
        patch :stop
        put :stop
        delete :remove_file
      end
    end

    resources :projects, only: [ :index, :create, :update, :destroy ]
    resources :clients, only: [ :index, :create, :update, :destroy ]
    resources :tags, only: [ :index, :create, :update, :destroy ]
    resources :memberships, only: [ :create, :destroy ]
    resources :workspace_invites, only: [ :destroy ], path: "invites"
    resources :invoices, only: [ :index, :show, :create, :update, :destroy ] do
      member do
        get :pdf
        post :send_email
      end
    end
  end

  resources :workspaces, only: [ :create ]
  patch "/workspaces/switch", to: "workspaces#switch", as: :switch_workspace

  root "marketing#home"
  get "/:workspace_id", to: "dashboard#index", constraints: { workspace_id: /[a-zA-Z0-9]+/ }

  get "up" => "rails/health#show", as: :rails_health_check
end
