Rails.application.routes.draw do
  resources :transactions      
  resources :overview, only: [:index]  
  resources :accounts
  resources :categories
  resources :account_types, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :category_groups, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :transaction_groups, only: [:index, :new, :create, :edit, :update, :destroy]

  root 'overview#index'
end
  