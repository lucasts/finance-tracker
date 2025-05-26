Rails.application.routes.draw do
  get 'categories/index'
  get 'categories/show'
  get 'categories/new'
  get 'categories/create'
  get 'categories/edit'
  get 'categories/update'
  get 'categories/destroy'
  get 'accounts/index'
  get 'accounts/show'
  get 'accounts/new'
  get 'accounts/create'
  get 'accounts/edit'
  get 'accounts/update'
  get 'accounts/destroy'
  resources :transactions
  root 'transactions#index'
    
  resources :overview, only: [:index]  
  resources :accounts
  resources :categories
  resources :account_types, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :category_groups, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :transaction_groups, only: [:index, :new, :create, :edit, :update, :destroy]


end
  