# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  respond_to :json

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end

  before_action :log_auth_header

  private

  def respond_with(resource, _opts = {})
    render json: {
      message: 'Logged in successfully.',
      user: resource
    }, status: :ok
  end

  def respond_to_on_destroy
    head :no_content
  end

  def log_auth_header
    Rails.logger.info "Authorization header: #{request.headers['Authorization']}"
  end
end
