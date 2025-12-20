Rails.application.routes.draw do
  get "versions/index"
  mount MissionControl::Jobs::Engine, at: "/jobs"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  # get  "sign_up", to: "registrations#new"
  # post "sign_up", to: "registrations#create"
  resources :users, only: [ :index ]
  resources :sessions, only: [ :index, :show, :destroy ]
  resource  :password, only: [ :edit, :update ]
  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end
  namespace :authentications do
    resources :events, only: :index
  end
  post "users/:user_id/masquerade", to: "masquerades#create", as: :user_masquerade
  namespace :sessions do
    resource :sudo, only: [ :new, :create ]
  end

  namespace :admin do
    resources :users
  end

  resource :dashboard, only: [ :show ] do
    post :scan
  end

  # --- Core Resources ---
  resources :branches

  resources :departments do
    collection do
      get :select_options
    end
  end

  resources :employees do
    collection do
      get :select_options # New endpoint
    end
  end

  # --- Network Management ---
  resources :subnets

  resources :ip_addresses, only: %i[index show edit update] do
    collection do
      get :select_options # New endpoint
    end
  end

  # --- Asset Management ---
  resources :devices do
    member do
      get :edit_status
    end

    collection do
      get :select_options
    end
  end

  # Auditing
  resources :versions, only: [:index]

  get "search", to: "search#index"

  # --- Root Path ---
  # The dashboard or main inventory list
  root "dashboards#show"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
