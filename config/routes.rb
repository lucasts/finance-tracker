Rails.application.routes.draw do
  # Health check endpoint
  get "/up" => "rails/health#show", as: :rails_health_check

  devise_for :users

  # Root route para usuários autenticados
  root "overview#index"

  resources :credit_statements, only: [ :index, :show ]
  resources :transactions
  resources :overview, only: [ :index ]
  resources :reports, only: [ :index ] do
    collection do
      get :variable_expenses_analysis
    end
  end
  resources :accounts
  resources :categories
  resources :account_types, only: [ :index, :new, :create, :edit, :update, :destroy ]

  resources :recurring_commitments do
    member do
      get :timeline
      patch :toggle_active
    end
  end

  resources :installment_plans do
    member do
      get :payment_schedule
      patch :toggle_active
      post :generate_missing_installments
    end
  end

  # Automation routes
  resources :automation, only: [ :index ] do
    collection do
      post :run_daily
      post :run_recurring
      post :run_installments
      get :status
      get :preview
    end
  end

  resources :import_sessions, only: [ :index, :new, :create, :show ] do
    member do
      get :confirm
      post :finalize
      post :batch_process_pending
    end
    resources :imported_transactions, only: [ :edit, :update ]
  end
  resources :reconciliation_entries, only: [ :create ]
end
