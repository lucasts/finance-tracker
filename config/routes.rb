Rails.application.routes.draw do
  resources :credit_statements, only: [:index, :show]  
  resources :transactions      
  resources :overview, only: [:index]  
  resources :reports, only: [:index] do
    collection do
      get :variable_expenses_analysis
    end
  end
  resources :accounts
  resources :categories
  resources :account_types, only: [:index, :new, :create, :edit, :update, :destroy]
  
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
  resources :automation, only: [:index] do
    collection do
      post :run_daily
      post :run_recurring
      post :run_installments
      get :status
    end
  end

  root 'overview#index'
end
