module Api
  class PaystackWebhooksController < ApplicationController
    # Skip authentication and CSRF token verification for webhooks
    skip_before_action :authenticate_request
    skip_before_action :verify_authenticity_token, raise: false

    # POST /api/paystack_callback
    def handle_callback
      request_body = request.body.read
      paystack_signature = request.headers['x-paystack-signature']

      Rails.logger.info "=== PAYSTACK WEBHOOK RECEIVED ==="
      Rails.logger.info "Request Headers: #{request.headers.to_h.inspect}"
      Rails.logger.info "Signature present: #{paystack_signature.present?}"
      Rails.logger.info "Body length: #{request_body.length}"
      Rails.logger.info "Raw body: #{request_body}"
      
      # 1. Parse the payload first to log event details
      begin
        payload = JSON.parse(request_body)
        Rails.logger.info "Webhook Event: #{payload['event']}"
        Rails.logger.info "Reference: #{payload.dig('data', 'reference')}"
        Rails.logger.info "Status: #{payload.dig('data', 'status')}"
      rescue JSON::ParserError => e
        Rails.logger.error "Invalid JSON in Paystack webhook: #{e.message}"
        render json: { status: 'error', message: 'Invalid JSON payload' }, status: :bad_request
        return
      end

      # 2. Verify the webhook signature for security (only in production)
      if Rails.env.production? && !verify_paystack_signature(request_body, paystack_signature)
        Rails.logger.error "WEBHOOK SIGNATURE VALIDATION FAILED"
        Rails.logger.error "Expected signature validation failed."
        render json: { status: 'error', message: 'Invalid signature' }, status: :bad_request
        return
      elsif Rails.env.development?
        Rails.logger.info "DEVELOPMENT MODE: Skipping signature verification"
      end

      # 3. IMMEDIATELY acknowledge receipt to Paystack
      render json: { status: 'success' }, status: :ok

      # 4. Process the webhook in background
      begin
        process_webhook_payload(payload)
      rescue => e
        Rails.logger.error "Error processing webhook: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    # Test endpoint for development
    def test_webhook
      Rails.logger.info "=== TESTING WEBHOOK PROCESSING ==="
      
      test_payload = {
        "event" => "charge.success",
        "data" => {
          "id" => "test_transaction_id_#{Time.current.to_i}",
          "reference" => params[:reference] || "ORDER_58_1757948983",
          "status" => "success",
          "channel" => "mobile_money",
          "amount" => 100, # 1 KES in kobo
          "currency" => "KES",
          "paid_at" => Time.current.iso8601,
          "customer" => {
            "email" => "test@example.com"
          }
        }
      }

      Rails.logger.info "Test payload: #{test_payload.inspect}"
      
      process_webhook_payload(test_payload)
      
      render json: { 
        status: 'success', 
        message: 'Test webhook processed successfully',
        payload: test_payload 
      }
    rescue => e
      Rails.logger.error "Test webhook error: #{e.message}"
      render json: { 
        status: 'error', 
        message: e.message 
      }, status: :internal_server_error
    end

    private

    def verify_paystack_signature(body, signature)
      return false if signature.blank?
      
      secret_key = ENV['PAYSTACK_WEBHOOK_SECRET']
      if secret_key.blank?
        Rails.logger.error "PAYSTACK_WEBHOOK_SECRET not found in environment variables"
        return false
      end

      digest = OpenSSL::Digest::SHA512.new
      hmac = OpenSSL::HMAC.hexdigest(digest, secret_key, body)
      
      Rails.logger.info "Generated HMAC: #{hmac}"
      Rails.logger.info "Received signature: #{signature}"
      
      # Use secure comparison to prevent timing attacks
      ActiveSupport::SecurityUtils.secure_compare(hmac, signature)
    end

    def process_webhook_payload(payload)
      event_type = payload['event']
      transaction_data = payload['data']
      reference = transaction_data['reference']

      Rails.logger.info "=== PROCESSING WEBHOOK ==="
      Rails.logger.info "Event: #{event_type}"
      Rails.logger.info "Reference: #{reference}"
      Rails.logger.info "Transaction ID: #{transaction_data['id']}"
      Rails.logger.info "Status: #{transaction_data['status']}"

      # Find the corresponding order using the Paystack reference
      order = Order.find_by(paystack_reference: reference)
      
      unless order
        Rails.logger.error "Order not found for reference: #{reference}"
        # Also try to find by transaction ID if reference fails
        order = Order.find_by(paystack_transaction_id: transaction_data['id'])
        unless order
          Rails.logger.error "Order also not found for transaction ID: #{transaction_data['id']}"
          return
        end
      end

      Rails.logger.info "Found Order ID: #{order.id}, Current Status: #{order.payment_status}"

      case event_type
      when 'charge.success'
        Rails.logger.info "=== PROCESSING SUCCESSFUL CHARGE ==="
        
        # Update order with success status
        order.update!(
          payment_status: 'Paystack Paid',
          status: 'confirmed',
          paystack_transaction_id: transaction_data['id'],
          paystack_status: transaction_data['status'],
          paystack_channel: transaction_data['channel'],
          paystack_amount: transaction_data['amount'].to_f / 100,
          paystack_currency: transaction_data['currency'] || 'KES'
        )

        Rails.logger.info "SUCCESS: Order #{order.id} updated to 'Paystack Paid'"

        # Clear user's cart
        if order.user.cart
          order.user.cart.cart_items.destroy_all
          Rails.logger.info "Cart cleared for user #{order.user.id}"
        end

        # Generate receipt (if service exists)
        begin
          if defined?(ReceiptGeneratorService)
            ReceiptGeneratorService.new(order).generate_pdf_and_attach
            Rails.logger.info "Receipt generated for Order #{order.id}"
          else
            Rails.logger.warn "ReceiptGeneratorService not found"
          end
        rescue => e
          Rails.logger.error "Failed to generate receipt: #{e.message}"
        end

      when 'charge.failed', 'charge.abandoned'
        Rails.logger.info "=== PROCESSING FAILED CHARGE ==="
        
        order.update!(
          payment_status: 'Paystack Failed',
          status: 'payment_failed',
          paystack_status: transaction_data['status'],
          paystack_channel: transaction_data['channel'] || 'unknown'
        )

        Rails.logger.warn "FAILED: Order #{order.id} marked as failed"

      when 'charge.pending'
        Rails.logger.info "=== PROCESSING PENDING CHARGE ==="
        
        order.update!(
          payment_status: 'Paystack Pending',
          status: 'processing',
          paystack_status: transaction_data['status'],
          paystack_channel: transaction_data['channel'] || 'unknown'
        )

        Rails.logger.info "PENDING: Order #{order.id} marked as pending"

      else
        Rails.logger.info "Unhandled event: #{event_type}"
      end

    rescue => e
      Rails.logger.error "Error processing webhook for #{reference}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end