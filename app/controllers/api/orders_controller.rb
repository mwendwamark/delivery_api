# app/controllers/api/orders_controller.rb
module Api
  class OrdersController < ApplicationController
    before_action :authenticate_request
    before_action :set_order, only: [:status, :download_receipt, :generate_receipt, :receipt_info]
    before_action :authorize_order_access, only: [:status, :download_receipt, :generate_receipt, :receipt_info]

    def status
      render json: {
        id: @order.id,
        payment_status: @order.payment_status,
        status: @order.status,
        receipt_url: @order.receipt_url,
        has_receipt: @order.has_receipt?
      }, status: :ok
    rescue => e
      Rails.logger.error "Error fetching order status for order ID #{params[:id]}: #{e.message}"
      render json: { error: 'An internal server error occurred.' }, status: :internal_server_error
    end

    def generate_receipt
      if @order.has_receipt?
        render json: { 
          message: 'Receipt already exists',
          receipt_url: @order.receipt_url,
          download_url: @order.receipt_download_url
        }
        return
      end

      receipt_url = @order.generate_and_store_receipt
      
      if receipt_url
        render json: { 
          message: 'Receipt generated successfully',
          receipt_url: receipt_url,
          download_url: @order.receipt_download_url
        }
      else
        render json: { 
          error: 'Failed to generate receipt' 
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error generating receipt for order ID #{params[:id]}: #{e.message}"
      render json: { error: 'An internal server error occurred while generating receipt.' }, status: :internal_server_error
    end

    def download_receipt
      unless @order.has_receipt?
        return render json: { 
          error: 'Receipt not found. Generate receipt first.' 
        }, status: :not_found
      end

      # Redirect to the presigned S3 URL for direct download
      redirect_to @order.receipt_download_url, allow_other_host: true
    rescue => e
      Rails.logger.error "Error downloading receipt for order ID #{params[:id]}: #{e.message}"
      render json: { error: 'An internal server error occurred while downloading receipt.' }, status: :internal_server_error
    end

    def receipt_info
      if @order.has_receipt?
        render json: {
          receipt_exists: true,
          receipt_url: @order.receipt_url,
          download_url: @order.receipt_download_url,
          created_at: @order.receipt.created_at,
          filename: @order.receipt.filename.to_s
        }
      else
        render json: {
          receipt_exists: false,
          message: 'No receipt generated for this order'
        }
      end
    rescue => e
      Rails.logger.error "Error fetching receipt info for order ID #{params[:id]}: #{e.message}"
      render json: { error: 'An internal server error occurred.' }, status: :internal_server_error
    end

    private

    def set_order
      @order = current_user.orders.find_by(id: params[:id])
      unless @order
        render json: { error: 'Order not found or unauthorized' }, status: :not_found
      end
    end

    def authorize_order_access
      # This method is called after set_order, so @order will be nil if not found
      # The set_order method already handles the authorization and error response
      return if @order.nil?
    end
  end
end