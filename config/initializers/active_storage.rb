Rails.application.configure do
  # ... existing code ...

  # Configure Active Storage URL generation
  config.active_storage.service_urls_expire_in = 1.hour
  config.active_storage.routes_prefix = "/rails/active_storage"
  config.active_storage.resolve_model_to_route = :rails_storage_proxy
end
