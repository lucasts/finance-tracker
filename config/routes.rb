Rails.application.routes.draw do
  resources :transactions
  root 'transactions#index'
    
  resources :overview, only: [:index]
  resources :transactions
  resources :accounts
  resources :categories

end
  