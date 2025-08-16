module Api
  class PaystackWebhooksController < ApplicationController
    # Skip authentication and CSRF token verification for webhooks
    skip_before_action :authenticate_request, :verify_authenticity_token

    # POST /api/paystack_callback
    # Handles incoming Paystack webhook events.
    def handle_callback
      request_body = request.body.read
      paystack_signature = request.headers['x-paystack-signature']

      # 1. Verify the webhook signature for security
      # This ensures the webhook truly came from Paystack and hasn't been tampered with.
      unless verify_paystack_signature(request_body, paystack_signature)
        Rails.logger.warn "Paystack Webhook: Invalid signature received."
        render json: { status: 'error', message: 'Invalid signature' }, status: :bad_request and return
      end

      # 2. Parse the payload
      payload = JSON.parse(request_body)
      Rails.logger.info "Paystack Webhook Received: #{payload.inspect}"

      # 3. Immediately acknowledge receipt to Paystack
      # This is CRUCIAL. Respond 200 OK quickly to prevent Paystack from retrying the webhook.
      render json: { status: 'success' }, status: :ok

      # 4. Offload heavy processing to a background job
      # This keeps the webhook endpoint fast and responsive.
      PaystackWebhookJob.perform_later(payload)

    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in Paystack webhook: #{e.message}"
      render json: { status: 'error', message: 'Invalid JSON payload' }, status: :bad_request
    rescue => e
      Rails.logger.error "Unexpected error in Paystack webhook handler: #{e.message}"
      render json: { status: 'error', message: 'Internal Server Error' }, status: :internal_server_error
    end

    private

    # Verifies the authenticity of the Paystack webhook by comparing signatures.
    def verify_paystack_signature(body, signature)
      digest = OpenSSL::Digest::SHA512.new
      hmac = OpenSSL::HMAC.hexdigest(digest, ENV['PAYSTACK_WEBHOOK_SECRET'], body)
      hmac == signature
    end
  end
end
