Rails.application.routes.draw do
    devise_for :users,
      defaults: { format: :json },
      controllers: {
        registrations: 'users/registrations',
        sessions: 'users/sessions'
      }
  get "up" => "rails/health#show", as: :rails_health_check

resources :products do
    resources :product_variants, shallow: true # This creates nested routes
  end
end
