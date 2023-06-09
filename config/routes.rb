Rails.application.routes.draw do
  devise_for :users
  root to: "gardens#index"

  resources :gardens, only: [:index, :show, :new, :create, :destroy] do
    get :compartments
    member do
      get :validate
    end
  end

  get '/gardens/:id/garden_created', to: 'gardens#garden_created', as: 'garden_created'
  post '/gardens/:id/implant', to: 'gardens#implant', as: 'implant'

  resources :vegetables, only: [:show]
end
