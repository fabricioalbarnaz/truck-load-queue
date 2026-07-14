Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount ActionCable.server => "/cable"

  namespace :registration do
    resources :drivers
    resources :trucks
    resources :visits, only: %i[index create]
  end

  namespace :expedition do
    resources :visits, only: %i[index] do
      member do
        patch :issue_order
      end
    end
  end

  namespace :queue, module: "queue_screen" do
    resources :visits, only: %i[index] do
      member do
        patch :finish
      end
    end
  end

  namespace :public do
    resource :queue, only: %i[show], controller: "queue"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#index"
end
