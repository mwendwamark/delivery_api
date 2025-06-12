# Create this file: app/controllers/concerns/jwt_token.rb

module JwtToken
  extend ActiveSupport::Concern

  included do
    # You can add before_actions here if needed
  end

  private

  def generate_jwt_token(user)
    payload = {
      user_id: user.id,
      email: user.email,
      role: user.role,
      first_name: user.first_name,
      last_name: user.last_name,
      exp: 24.hours.from_now.to_i  # Token expires in 24 hours
    }
    
    JWT.encode(payload, jwt_secret, 'HS256')
  end

  def decode_jwt_token(token)
    JWT.decode(token, jwt_secret, true, { algorithm: 'HS256' })
  rescue JWT::DecodeError => e
    Rails.logger.error "JWT Decode Error: #{e.message}"
    nil
  end

  def jwt_secret
    Rails.application.credentials.secret_key_base || Rails.application.secrets.secret_key_base
  end
end