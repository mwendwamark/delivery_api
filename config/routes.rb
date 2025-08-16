Rails.application.routes.draw do
  devise_for :users,
    defaults: { format: :json },
    controllers: {
      registrations: "users/registrations",
      sessions: "users/sessions",
    }
  get "up" => "rails/health#show", as: :rails_health_check

  resources :products do
    resources :product_variants, shallow: true
  end
  
  resource :cart, only: [:show] do
    post "add_item/:product_id", to: "carts#add_item", as: "add_item"
    delete "remove_item/:product_id", to: "carts#remove_item", as: "remove_item"
    patch "update_item/:product_id", to: "carts#update_item", as: "update_item"
  end

  # --- API ROUTES FOR PAYSTACK & ORDERS ---
  namespace :api do
    # Paystack payment initiation
    post 'paystack_initiate_payment', to: 'paystack_payments#initiate'
    
    # Paystack webhook callback endpoint (MUST match the URL registered in Paystack dashboard)
    post 'paystack_callback', to: 'paystack_webhooks#handle_callback'

    # Orders routes
    resources :orders, only: [] do
      member do
        get 'status'   # GET /api/orders/:id/status
        get 'receipt'  # GET /api/orders/:id/receipt
      end
      collection do
        post 'create_cash_on_delivery'  # FIXED: Added missing 'e'
      end
    end
  end
end