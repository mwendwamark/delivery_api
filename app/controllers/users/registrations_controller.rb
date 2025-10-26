# # frozen_string_literal: true

# class Users::RegistrationsController < Devise::RegistrationsController
#   respond_to :json

#   before_action :configure_sign_up_params, only: [:create]
#   before_action :configure_account_update_params, only: [:update]

#   # GET /resource/sign_up
#   # def new
#   #   super
#   # end

#   # POST /resource
#   # def create
#   #   super
#   # end

#   # GET /resource/edit
#   # def edit
#   #   super
#   # end

#   # PUT /resource
#   # def update
#   #   super
#   # end

#   # DELETE /resource
#   # def destroy
#   #   super
#   # end

#   # GET /resource/cancel
#   # Forces the session data which is usually expired after sign
#   # in to be expired now. This is useful if the user wants to
#   # cancel oauth signing in/up in the middle of the process,
#   # removing all OAuth session data.
#   # def cancel
#   #   super
#   # end

#   protected

#   def configure_sign_up_params
#     devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number, :role, :date_of_birth])
#   end

#   def configure_account_update_params
#     devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone_number, :role, :date_of_birth])
#   end

#   # The path used after sign up.
#   # def after_sign_up_path_for(resource)
#   #   super(resource)
#   # end

#   # The path used after sign up for inactive accounts.
#   # def after_inactive_sign_up_path_for(resource)
#   #   super(resource)
#   # end

#   private

#   def sign_up_params
#     params.require(:user).permit(:email, :password, :password_confirmation, :role, :first_name, :last_name, :phone_number, :date_of_birth)
#   end

#   def account_update_params
#     params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :role, :first_name, :last_name, :phone_number, :date_of_birth)
#   end

#   def respond_with(resource, _opts = {})
#     if resource.persisted?
#       render json: { message: 'Signed up successfully.', user: resource }, status: :created
#     else
#       render json: { error: resource.errors.full_messages }, status: :unprocessable_entity
#     end
#   end

#   def sign_up(resource_name, resource)
#     # Do nothing to avoid session creation
#   end
# end


# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  def create
    build_resource(sign_up_params)

    # Debug logging
    Rails.logger.info "Sign up params: #{sign_up_params.inspect}"
    Rails.logger.info "Resource date_of_birth: #{resource.date_of_birth}"
    Rails.logger.info "Resource age: #{resource.age}"
    Rails.logger.info "Resource age_verified?: #{resource.age_verified?}"

    resource.save
    yield resource if block_given?
    if resource.persisted?
      if resource.active_for_authentication?
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number, :role, :date_of_birth])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone_number, :role, :date_of_birth])
  end

  private

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role, :first_name, :last_name, :phone_number, :date_of_birth)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :role, :first_name, :last_name, :phone_number, :date_of_birth)
  end

  def respond_with(resource, _opts = {})
    if resource.persisted?
      Rails.logger.info "User created successfully with date_of_birth: #{resource.date_of_birth}"
      Rails.logger.info "Age verified: #{resource.age_verified?}"
      
      render json: { 
        message: 'Signed up successfully.', 
        user: {
          id: resource.id,
          email: resource.email,
          first_name: resource.first_name,
          last_name: resource.last_name,
          phone_number: resource.phone_number,
          role: resource.role,
          date_of_birth: resource.date_of_birth,
          age_verified: resource.age_verified? # Remove ? from key name
        }
      }, status: :created
    else
      render json: { error: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def sign_up(resource_name, resource)
    # Do nothing to avoid session creation for API-only
  end
end