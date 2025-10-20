class ApplicationController < ActionController::API
  include JwtToken
  before_action :authenticate_request
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number, :role, :date_of_birth])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone_number, :role, :date_of_birth])
  end

  private

  def authenticate_request
    # Skip authentication for signup and login routes
    return if devise_controller? && (action_name == "create" || action_name == "new")

    header = request.headers["Authorization"]
    if header.nil?
      render json: { error: "Authorization header missing" }, status: :unauthorized
      return
    end

    begin
      token = header.split(" ").last
      decoded = decode_jwt_token(token)

      if decoded.nil?
        render json: { error: "Invalid token" }, status: :unauthorized
        return
      end

      @current_user = User.find(decoded[0]["user_id"])
    rescue JWT::ExpiredSignature
      render json: { error: "Token has expired" }, status: :unauthorized
    rescue JWT::DecodeError => e
      render json: { error: "Invalid token" }, status: :unauthorized
    rescue ActiveRecord::RecordNotFound
      render json: { error: "User not found" }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end
end
