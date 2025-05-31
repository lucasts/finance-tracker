Rails.application.routes.draw do
  resources :credit_statements, only: [:index, :show]  
  resources :transactions      
  resources :overview, only: [:index]  
  resources :reports, only: [:index]
  resources :accounts
  resources :categories
  resources :account_types, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :transaction_groups

  root 'overview#index'
end
  