Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :orders, only: [:create]
    end
  end

  get "d/:token", to: "downloads#show", as: :download_landing
  post "d/:token", to: "downloads#download", as: :download_confirm

  get "up" => "rails/health#show", as: :rails_health_check
end
