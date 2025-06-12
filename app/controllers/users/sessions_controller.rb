# # frozen_string_literal: true

# class Users::SessionsController < Devise::SessionsController
#   respond_to :json

#   before_action :log_auth_header

#   private

#   def respond_with(resource, _opts = {})
#     render json: {
#       message: 'Logged in successfully.',
#       user: resource
#     }, status: :ok
#   end

#   def respond_to_on_destroy
#     head :no_content
#   end

#   def log_auth_header
#     Rails.logger.info "Authorization header: #{request.headers['Authorization']}"
#   end
# end

# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  include JwtToken  # Include the JWT concern
  
  respond_to :json
  before_action :log_auth_header

  private

  def respond_with(resource, _opts = {})
    # Generate JWT token for the authenticated user
    token = generate_jwt_token(resource)
    
    render json: {
      message: 'Logged in successfully.',
      user: {
        id: resource.id,
        email: resource.email,
        first_name: resource.first_name,
        last_name: resource.last_name,
        role: resource.role,
        phone_number: resource.phone_number
      },
      token: token
    }, status: :ok
  end

  def respond_to_on_destroy
    # Clear any server-side session if needed
    render json: {
      message: 'Logged out successfully.'
    }, status: :ok
  end

  def log_auth_header
    Rails.logger.info "Authorization header: #{request.headers['Authorization']}"
  end
end