Rails.application.routes.draw do
  devise_for :users,
    defaults: { format: :json },
    controllers: {
      registrations: "users/registrations",
      sessions: "users/sessions",
    }
  get "up" => "rails/health#show", as: :rails_health_check

  resources :products do
    resources :product_variants, shallow: true # This creates nested routes
  end
  resource :cart, only: [:show] do
    post "add_item/:product_id", to: "carts#add_item", as: "add_item"
    delete "remove_item/:product_id", to: "carts#remove_item", as: "remove_item"
    patch "update_item/:product_id", to: "carts#update_item", as: "update_item"
  end
end
