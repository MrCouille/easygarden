Rails.application.routes.draw do
  devise_for :users
  root to: "gardens#index"

  resources :gardens, only: [:index, :show, :new, :create, :destroy] do
    member do
      get :compartments
      get :created
      post :implant
      get :implanted
      post :validate
    end
  end

  # Catalog view
  resources :vegetables, only: [:index, :show]
end
