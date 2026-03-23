Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/login",    to: "auth#login"
      post "auth/register", to: "auth#register"

      resources :units, only: [:index, :show, :create, :update] do
        member { get :available_slots }
      end

      resources :appointments, only: [:index, :create, :update, :destroy]

      resources :applications, only: [:index, :create, :destroy] do
        member do
          patch :approve
          patch :reject
        end
      end

      resources :leases, only: [:index, :show, :create, :update] do
        member do
          post :renew
          post :send_agreement
        end
      end

      resources :letters, only: [:index] do
        member { post :sign }
      end

      resources :invoices, only: [:index, :show] do
        collection do
          post :generate
          post :regenerate
        end
        member { patch :utilities }
      end

      resources :payments, only: [:create]

      resources :maintenance_tickets, only: [:index, :create, :update] do
        member { post :bill_damage }
      end

      resources :utility_consumptions, only: [:index, :show]

      namespace :reports do
        get :occupancy
        get :revenue
        get :maintenance
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
