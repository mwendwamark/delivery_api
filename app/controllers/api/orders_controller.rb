# app/controllers/api/orders_controller.rb
module Api
  class OrdersController < ApplicationController
    # Skip authentication for status check if you want unauthenticated users to track
    # based on a public order ID or reference. Otherwise, keep authenticate_request.
    # For now, let's assume authenticated users track their own orders.
    # skip_before_action :authenticate_request, only: [:status, :download_receipt] # If you want public tracking

    # GET /api/orders/:id/status
    # Allows frontend to poll for the latest status of a specific order.
    def status
      order = current_user.orders.find_by(id: params[:id]) # Ensure user owns the order
      unless order
        render json: { error: 'Order not found or unauthorized' }, status: :not_found and return
      end

      render json: {
        id: order.id,
        payment_status: order.payment_status,
        status: order.status,
        receipt_url: order.receipt_url # Include receipt URL if available
      }, status: :ok
    rescue => e
      Rails.logger.error "Error fetching order status for order ID #{params[:id]}: #{e.message}"
      render json: { error: 'An internal server error occurred.' }, status: :internal_server_error
    end

    # GET /api/orders/:id/receipt
    # Serves the generated PDF receipt for download.
    def download_receipt
      order = current_user.orders.find_by(id: params[:id]) # Ensure user owns the order
      unless order && order.receipt_url.present?
        render json: { error: 'Order or receipt not found' }, status: :not_found and return
      end

      # Construct the full path to the PDF file in the public directory
      pdf_path = Rails.root.join('public', order.receipt_url.delete_prefix('/')) # Remove leading slash if any

      if File.exist?(pdf_path)
        send_file pdf_path,
                  type: 'application/pdf',
                  disposition: 'attachment', # Forces download
                  filename: "receipt_order_#{order.id}.pdf"
      else
        Rails.logger.error "Receipt file not found at #{pdf_path} for Order #{order.id}"
        render json: { error: 'Receipt file not found on server.' }, status: :not_found
      end
    rescue => e
      Rails.logger.error "Error downloading receipt for order ID #{params[:id]}: #{e.message}"
      render json: { error: 'An internal server error occurred.' }, status: :internal_server_error
    end

    # POST /api/orders/create_cash_on_delivery
    # Creates an order with 'Cash on Delivery' payment method.
    # Supports both saved addresses and manual addresses
    def create_cash_on_delivery
      # Parameters from frontend:
      # amount: total price of the order
      # cart_items: array of cart items (to create OrderItems)
      # delivery_address_id: ID of the selected delivery address (for saved addresses)
      # OR
      # manual_address: { location, street_address, latitude, longitude, recipient_name, recipient_phone } (for manual addresses)

      # Basic validation
      unless params[:amount].present? && params[:cart_items].present?
        render json: { error: 'Missing required parameters: amount and cart_items are required' }, status: :bad_request and return
      end

      order_total_price = params[:amount].to_i # Ensure integer for total_price in DB
      
      # Handle address - either use existing or create a manual one
      if params[:delivery_address_id].present?
        # Use existing address
        delivery_address = Address.find_by(id: params[:delivery_address_id], user: current_user)
        
        unless delivery_address
          render json: { error: 'Invalid delivery address selected or not owned by user' }, status: :unprocessable_entity and return
        end
      elsif params[:manual_address].present?
        # Create a new manual address
        delivery_address = Address.create_manual_address(
          current_user,
          params.require(:manual_address).permit(:location, :street_address, :latitude, :longitude, :recipient_name, :recipient_phone)
        )
        
        unless delivery_address.persisted?
          render json: { error: 'Invalid address details', errors: delivery_address.errors.full_messages }, status: :unprocessable_entity and return
        end
      else
        render json: { error: 'Either delivery_address_id or manual_address must be provided' }, status: :bad_request and return
      end

      # Create the Order record
      order = Order.new(
        user: current_user,
        address: delivery_address,
        total_price: order_total_price,
        delivery_instructions: params[:delivery_instructions], # Optional
        payment_status: 'Cash on Delivery', # Set payment status directly
        status: 'confirmed' # Order is confirmed for COD
      )

      # Create OrderItems from cart_items passed from frontend
      params[:cart_items].each do |item|
        product = Product.find_by(id: item[:product_id])
        if product
          order.order_items.build(
            product: product,
            quantity: item[:quantity],
            size: item[:size],
            price_per_unit: item[:price_per_unit]
          )
        else
          # If a product in the cart is not found, invalidate the order or handle appropriately
          order.errors.add(:base, "Product with ID #{item[:product_id]} not found.")
          render json: { error: order.errors.full_messages }, status: :unprocessable_entity and return
        end
      end

      if order.save
        # Clear the user's cart after successful order creation
        current_user.cart.cart_items.destroy_all if current_user.cart

        # Optionally generate a "receipt" for COD (less critical than online payments)
        # For simplicity, we won't generate a PDF for COD here, but you could.
        # If you want a PDF for COD, uncomment and adjust:
        # ReceiptGeneratorService.new(order).generate_pdf_and_attach

        render json: {
          message: 'Cash on Delivery order placed successfully',
          order_id: order.id,
          payment_status: order.payment_status,
          status: order.status,
          receipt_url: order.receipt_url # Will be nil unless PDF generated
        }, status: :created
      else
        render json: { error: order.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error creating Cash on Delivery order: #{e.message}"
      render json: { error: 'An internal server error occurred during COD order creation.' }, status: :internal_server_error
    end
  end
end
