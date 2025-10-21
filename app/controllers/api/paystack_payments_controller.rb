# app/controllers/api/paystack_payments_controller.rb
module Api
  class PaystackPaymentsController < ApplicationController
    # POST /api/paystack_initiate_payment
    def initiate
      # 1. Validate required parameters
      unless params[:amount].present? && params[:email].present? && params[:cart_items].present?
        render json: { error: "Missing required parameters: amount, email, cart_items" }, status: :bad_request
        return
      end

      begin
        # 2. Get the delivery address, handling both manual and saved addresses
        delivery_address = nil

        if params[:delivery_address_id].present?
          # If a saved address ID is provided, find it for the current user
          delivery_address = current_user.addresses.find_by(id: params[:delivery_address_id])
          unless delivery_address
            render json: { error: "Invalid delivery address ID" }, status: :unprocessable_entity
            return
          end
        elsif params[:manual_address].present?
          # If manual address data is provided, create a new address record
          manual_address_data = params.require(:manual_address).permit(
            :recipient_name,
            :recipient_phone,
            :street_address,
            :location,
            :latitude,
            :longitude
          )

          # Mark as manual address
          manual_address_data[:is_manual] = true

          delivery_address = current_user.addresses.new(manual_address_data)
          unless delivery_address.save
            render json: { error: delivery_address.errors.full_messages }, status: :unprocessable_entity
            return
          end
        else
          # If neither a saved address nor manual data is present, return an error
          render json: { error: "Delivery address or manual address data is required" }, status: :unprocessable_entity
          return
        end

        # 3. Get delivery instructions (NEW)
        delivery_instructions = params[:delivery_instructions].presence

        # 4. Create the order (pending payment) with the determined address and delivery instructions
        order = Order.new(
          user: current_user,
          shipping_address_id: delivery_address.id,
          total_price: params[:amount].to_i,
          payment_status: "pending",
          status: "processing",
          delivery_instructions: delivery_instructions,  # NEW: Store delivery instructions
          payment_method: "paystack",
        )

        # 5. Create order items
        params[:cart_items].each do |item|
          product = Product.find_by(id: item[:product_id])
          if product
            order.order_items.build(
              product: product,
              quantity: item[:quantity],
              size: item[:size],
              price_per_unit: item[:price_per_unit],
            )
          end
        end

        if order.save
          # 6. Generate Paystack reference and initiate transaction
          reference = "ORDER_#{order.id}_#{Time.current.to_i}"
          paystack_service = PaystackService.new

          # Use the ngrok URL for webhook, not callback
          webhook_url = "https://282ace648f6a.ngrok-free.app/api/paystack_callback"

          paystack_response = paystack_service.initialize_transaction(
            email: params[:email],
            amount: (params[:amount].to_f * 100).to_i, # Convert to kobo
            reference: reference,
            callback_url: webhook_url, # This will be used for both callback and webhook
          )

          Rails.logger.info "=== PAYSTACK INITIALIZATION ==="
          Rails.logger.info "Order ID: #{order.id}"
          Rails.logger.info "Reference: #{reference}"
          Rails.logger.info "Delivery Instructions: #{delivery_instructions}"
          Rails.logger.info "Paystack Response: #{paystack_response.inspect}"

          if paystack_response[:status]
            # Update order with Paystack reference and transaction ID
            order.update!(
              paystack_reference: reference,
              paystack_transaction_id: paystack_response.dig(:data, :id),
            )

            Rails.logger.info "Order updated with Paystack details: Reference=#{reference}, Transaction_ID=#{paystack_response.dig(:data, :id)}"

            render json: {
              status: true,
              message: "Transaction initialized successfully",
              order_id: order.id,
              reference: reference,
              authorization_url: paystack_response[:data][:authorization_url],
              access_code: paystack_response[:data][:access_code],
              delivery_instructions: delivery_instructions,  # NEW: Return delivery instructions
            }, status: :ok
          else
            # Delete the order if Paystack initialization fails
            order.destroy
            render json: {
              error: "Failed to initialize payment with Paystack",
              details: paystack_response[:message],
            }, status: :unprocessable_entity
          end
        else
          render json: { error: order.errors.full_messages }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Error initiating Paystack payment: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: "Internal server error" }, status: :internal_server_error
      end
    end

    # POST /api/paystack_create_cash_on_delivery (NEW METHOD - Add this)
    def create_cash_on_delivery
      # 1. Validate required parameters
      unless params[:amount].present? && params[:cart_items].present?
        render json: { error: "Missing required parameters: amount, cart_items" }, status: :bad_request
        return
      end

      begin
        # 2. Get the delivery address, handling both manual and saved addresses
        delivery_address = nil

        if params[:delivery_address_id].present?
          # If a saved address ID is provided, find it for the current user
          delivery_address = current_user.addresses.find_by(id: params[:delivery_address_id])
          unless delivery_address
            render json: { error: "Invalid delivery address ID" }, status: :unprocessable_entity
            return
          end
        elsif params[:manual_address].present?
          # If manual address data is provided, create a new address record
          manual_address_data = params.require(:manual_address).permit(
            :recipient_name,
            :recipient_phone,
            :street_address,
            :location,
            :latitude,
            :longitude
          )

          # Mark as manual address
          manual_address_data[:is_manual] = true

          delivery_address = current_user.addresses.new(manual_address_data)
          unless delivery_address.save
            render json: { error: delivery_address.errors.full_messages }, status: :unprocessable_entity
            return
          end
        else
          # If neither a saved address nor manual data is present, return an error
          render json: { error: "Delivery address or manual address data is required" }, status: :unprocessable_entity
          return
        end

        # 3. Get delivery instructions
        delivery_instructions = params[:delivery_instructions].presence

        # 4. Create the order (Cash on Delivery) with the determined address and delivery instructions
        order = Order.new(
          user: current_user,
          shipping_address_id: delivery_address.id,
          total_price: params[:amount].to_i,
          payment_status: "Cash on Delivery",
          status: "confirmed",
          delivery_instructions: delivery_instructions,  # Store delivery instructions
          payment_method: "cash_on_delivery",
        )

        # 5. Create order items
        params[:cart_items].each do |item|
          product = Product.find_by(id: item[:product_id])
          if product
            order.order_items.build(
              product: product,
              quantity: item[:quantity],
              size: item[:size],
              price_per_unit: item[:price_per_unit],
            )
          end
        end

        if order.save
          Rails.logger.info "=== CASH ON DELIVERY ORDER CREATED ==="
          Rails.logger.info "Order ID: #{order.id}"
          Rails.logger.info "Delivery Instructions: #{delivery_instructions}"
          Rails.logger.info "Address: #{delivery_address.full_address}"

          # Generate receipt (optional)
          receipt_url = order.generate_and_store_receipt rescue nil

          render json: {
            status: true,
            message: "Order placed successfully",
            order_id: order.id,
            payment_status: order.payment_status,
            order_status: order.status,
            receipt_url: receipt_url,
            delivery_instructions: delivery_instructions,
          }, status: :created
        else
          render json: { error: order.errors.full_messages }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Error creating Cash on Delivery order: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: "Internal server error" }, status: :internal_server_error
      end
    end
  end
end
