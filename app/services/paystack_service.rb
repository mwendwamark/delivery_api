# app/services/paystack_service.rb
class PaystackService
  include HTTParty
  base_uri 'https://api.paystack.co'

  def initialize
    @secret_key = ENV['PAYSTACK_SECRET_KEY']
    raise 'PAYSTACK_SECRET_KEY not found in environment variables' unless @secret_key
  end

  def initialize_transaction(email:, amount:, reference:, callback_url: nil)
    options = {
      headers: {
        'Authorization' => "Bearer #{@secret_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        email: email,
        amount: amount,
        reference: reference,
        callback_url: callback_url
      }.to_json
    }

    response = self.class.post('/transaction/initialize', options)
    
    if response.success?
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        status: false,
        message: "HTTP Error: #{response.code} - #{response.message}"
      }
    end
  rescue => e
    Rails.logger.error "PaystackService error: #{e.message}"
    {
      status: false,
      message: "Service error: #{e.message}"
    }
  end

  def verify_transaction(reference)
    options = {
      headers: {
        'Authorization' => "Bearer #{@secret_key}",
        'Content-Type' => 'application/json'
      }
    }

    response = self.class.get("/transaction/verify/#{reference}", options)
    
    if response.success?
      JSON.parse(response.body, symbolize_names: true)
    else
      {
        status: false,
        message: "HTTP Error: #{response.code} - #{response.message}"
      }
    end
  rescue => e
    Rails.logger.error "PaystackService verify error: #{e.message}"
    {
      status: false,
      message: "Service error: #{e.message}"
    }
  end
end