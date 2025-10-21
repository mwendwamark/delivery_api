# Rails.application.routes.draw do
#   devise_for :users,
#     defaults: { format: :json },
#     controllers: {
#       registrations: "users/registrations",
#       sessions: "users/sessions",
#     }
  
#   get "up" => "rails/health#show", as: :rails_health_check

#   resources :products do
#     resources :product_variants, shallow: true
#   end
  
#   resource :cart, only: [:show] do
#     post "add_item/:product_id", to: "carts#add_item", as: "add_item"
#     delete "remove_item/:product_id", to: "carts#remove_item", as: "remove_item"
#     patch "update_item/:product_id", to: "carts#update_item", as: "update_item"
#   end

#   # --- API ROUTES ---
#   namespace :api do
#     # USERS ROUTES - ADD THIS
#     resources :users, only: [:index, :show, :update, :destroy]
    
#     # Paystack payment initiation
#     post 'paystack_initiate_payment', to: 'paystack_payments#initiate'
    
#     # Paystack webhook callback endpoint
#     post 'paystack_callback', to: 'paystack_webhooks#handle_callback'
#     get 'paystack_callback', to: 'paystack_webhooks#handle_callback'
    
#     # Development and testing endpoints
#     if Rails.env.development? || Rails.env.test?
#       post 'test_webhook', to: 'paystack_webhooks#test_webhook'
#       get 'test_webhook/:reference', to: 'paystack_webhooks#test_webhook'
#       get 'debug_order/:id', to: 'orders#debug_order'
#     end

#     # Orders routes
#     resources :orders, only: [:index] do
#       member do
#         get 'status'
#         get 'receipt'
#         post 'generate_receipt'
#         get 'receipt_info'
#       end
#       collection do
#         post 'create_cash_on_delivery'
#       end
#     end
#   end
# end

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

  # --- API ROUTES ---
  namespace :api do
    # USERS ROUTES
    resources :users, only: [:index, :show, :update, :destroy]
    
    # Paystack payment routes
    post 'paystack_initiate_payment', to: 'paystack_payments#initiate'
    post 'paystack_create_cash_on_delivery', to: 'paystack_payments#create_cash_on_delivery'
    
    # Paystack webhook callback endpoint
    post 'paystack_callback', to: 'paystack_webhooks#handle_callback'
    get 'paystack_callback', to: 'paystack_webhooks#handle_callback'
    
    # Development and testing endpoints
    if Rails.env.development? || Rails.env.test?
      post 'test_webhook', to: 'paystack_webhooks#test_webhook'
      get 'test_webhook/:reference', to: 'paystack_webhooks#test_webhook'
      get 'debug_order/:id', to: 'orders#debug_order'
    end

    # Orders routes
    resources :orders, only: [:index] do
      member do
        get 'status'
        get 'receipt'
        post 'generate_receipt'
        get 'receipt_info'
      end
    end
  end
end