# # app/controllers/api/orders_controller.rb
# module Api
#   class OrdersController < ApplicationController
#     before_action :authenticate_request
#     before_action :set_order, only: [:status, :download_receipt, :generate_receipt, :receipt_info]
#     before_action :authorize_order_access, only: [:status, :download_receipt, :generate_receipt, :receipt_info]

#     ORDERS_PER_PAGE = 15

#     def index
#       orders = current_user.orders
#                  .includes(:order_items, :shipping_address, :billing_address)
#                  .order(created_at: :desc)

#       # Apply filters
#       orders = filter_by_status(orders)
#       orders = filter_by_date_range(orders)
#       orders = search_by_order_id(orders)

#       # Paginate results
#       @orders = orders.page(params[:page]).per(params[:per_page] || ORDERS_PER_PAGE)

#       render json: {
#         orders: @orders.as_json(include: order_includes),
#         meta: pagination_meta(@orders)
#       }
#     rescue => e
#       Rails.logger.error "Error fetching orders: #{e.message}"
#       render json: { error: 'Failed to fetch orders' }, status: :internal_server_error
#     end

#     def status
#       render json: {
#         id: @order.id,
#         payment_status: @order.payment_status,
#         status: @order.status,
#         receipt_url: @order.receipt_url,
#         has_receipt: @order.has_receipt?
#       }, status: :ok
#     rescue => e
#       Rails.logger.error "Error fetching order status for order ID #{params[:id]}: #{e.message}"
#       render json: { error: 'An internal server error occurred.' }, status: :internal_server_error
#     end

#     def generate_receipt
#       if @order.has_receipt?
#         render json: {
#           message: 'Receipt already exists',
#           receipt_url: @order.receipt_url,
#           download_url: @order.receipt_download_url
#         }
#         return
#       end

#       receipt_url = @order.generate_and_store_receipt

#       if receipt_url
#         render json: {
#           message: 'Receipt generated successfully',
#           receipt_url: receipt_url,
#           download_url: @order.receipt_download_url
#         }
#       else
#         render json: {
#           error: 'Failed to generate receipt'
#         }, status: :unprocessable_entity
#       end
#     rescue => e
#       Rails.logger.error "Error generating receipt for order ID #{params[:id]}: #{e.message}"
#       render json: { error: 'An internal server error occurred while generating receipt.' }, status: :internal_server_error
#     end

#     def download_receipt
#       unless @order.has_receipt?
#         return render json: {
#           error: 'Receipt not found. Generate receipt first.'
#         }, status: :not_found
#       end

#       # Redirect to the presigned S3 URL for direct download
#       redirect_to @order.receipt_download_url, allow_other_host: true
#     rescue => e
#       Rails.logger.error "Error downloading receipt for order ID #{params[:id]}: #{e.message}"
#       render json: { error: 'An internal server error occurred while downloading receipt.' }, status: :internal_server_error
#     end

#     def receipt_info
#       if @order.has_receipt?
#         render json: {
#           receipt_exists: true,
#           receipt_url: @order.receipt_url,
#           download_url: @order.receipt_download_url,
#           created_at: @order.receipt.created_at,
#           filename: @order.receipt.filename.to_s
#         }
#       else
#         render json: {
#           receipt_exists: false,
#           message: 'No receipt generated for this order'
#         }
#       end
#     rescue => e
#       Rails.logger.error "Error fetching receipt info for order ID #{params[:id]}: #{e.message}"
#     end

#     private

#     def set_order
#       @order = Order.find_by(id: params[:id])
#       render json: { error: 'Order not found' }, status: :not_found unless @order
#     end

#     def authorize_order_access
#       unless @order.user_id == current_user.id || current_user.admin?
#         render json: { error: 'Not authorized' }, status: :forbidden
#       end
#     end

#     def filter_by_status(orders)
#       return orders unless params[:status].present?

#       case params[:status].downcase
#       when 'all'
#         orders
#       when 'pending'
#         orders.where(status: 'pending')
#       when 'confirmed'
#         orders.where(status: 'confirmed')
#       when 'preparing'
#         orders.where(status: 'preparing')
#       when 'out_for_delivery'
#         orders.where(status: 'out_for_delivery')
#       when 'delivered'
#         orders.where(status: 'delivered')
#       when 'cancelled'
#         orders.where(status: 'cancelled')
#       else
#         orders
#       end
#     end

#     def filter_by_date_range(orders)
#       return orders unless params[:date_range].present?

#       case params[:date_range].downcase
#       when '30d'
#         orders.where('created_at >= ?', 30.days.ago)
#       when '6m'
#         orders.where('created_at >= ?', 6.months.ago)
#       when '1y'
#         orders.where('created_at >= ?', 1.year.ago)
#       else
#         orders
#       end
#     end

#     def search_by_order_id(orders)
#       return orders unless params[:search].present?
#       orders.where('id::text LIKE ?', "%#{params[:search]}%")
#     end

#     def order_includes
#       {
#         order_items: {
#           include: {
#             product: {
#               only: [:id, :name, :description, :image_url, :category]
#             }
#           },
#           methods: [:item_total]
#         },
#         shipping_address: {
#           only: [:id, :street, :city, :state, :postal_code, :country, :phone]
#         },
#         billing_address: {
#           only: [:id, :street, :city, :state, :postal_code, :country, :phone]
#         }
#       }
#     end

#     def pagination_meta(collection)
#       {
#         current_page: collection.current_page,
#         next_page: collection.next_page,
#         prev_page: collection.prev_page,
#         total_pages: collection.total_pages,
#         total_count: collection.total_count
#       }
#     end
#   end
# end

module Api
  class OrdersController < ApplicationController
    before_action :authenticate_request
    before_action :set_order, only: [:status, :download_receipt, :generate_receipt, :receipt_info]
    before_action :authorize_order_access, only: [:status, :download_receipt, :generate_receipt, :receipt_info]

    ORDERS_PER_PAGE = 15

    def index
      # CHANGED: Admins can see all orders, regular users only see their own
      if current_user.admin?
        orders = Order.all
      else
        orders = current_user.orders
      end

      orders = orders.includes(:order_items, :shipping_address, :billing_address)
                     .order(created_at: :desc)

      # Apply filters
      orders = filter_by_status(orders)
      orders = filter_by_date_range(orders)
      orders = search_by_order_id(orders)

      # Get total count before pagination
      total_count = orders.count

      # Manual pagination
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || ORDERS_PER_PAGE).to_i
      offset = (page - 1) * per_page

      paginated_orders = orders.limit(per_page).offset(offset)
      total_pages = (total_count.to_f / per_page).ceil

      render json: {
        orders: paginated_orders.as_json(include: order_includes),
        meta: {
          current_page: page,
          next_page: page < total_pages ? page + 1 : nil,
          prev_page: page > 1 ? page - 1 : nil,
          total_pages: total_pages,
          total_count: total_count,
        },
      }
    rescue => e
      Rails.logger.error "Error fetching orders: #{e.message}"
      render json: { error: "Failed to fetch orders" }, status: :internal_server_error
    end

    def status
      render json: {
        id: @order.id,
        payment_status: @order.payment_status,
        status: @order.status,
        receipt_url: @order.receipt_url,
        has_receipt: @order.has_receipt?,
      }, status: :ok
    rescue => e
      Rails.logger.error "Error fetching order status for order ID #{params[:id]}: #{e.message}"
      render json: { error: "An internal server error occurred." }, status: :internal_server_error
    end

    def generate_receipt
      if @order.has_receipt?
        render json: {
          message: "Receipt already exists",
          receipt_url: @order.receipt_url,
          download_url: @order.receipt_download_url,
        }
        return
      end

      receipt_url = @order.generate_and_store_receipt

      if receipt_url
        render json: {
          message: "Receipt generated successfully",
          receipt_url: receipt_url,
          download_url: @order.receipt_download_url,
        }
      else
        render json: {
          error: "Failed to generate receipt",
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error generating receipt for order ID #{params[:id]}: #{e.message}"
      render json: { error: "An internal server error occurred while generating receipt." }, status: :internal_server_error
    end

    def download_receipt
      unless @order.has_receipt?
        return render json: {
                        error: "Receipt not found. Generate receipt first.",
                      }, status: :not_found
      end

      redirect_to @order.receipt_download_url, allow_other_host: true
    rescue => e
      Rails.logger.error "Error downloading receipt for order ID #{params[:id]}: #{e.message}"
      render json: { error: "An internal server error occurred while downloading receipt." }, status: :internal_server_error
    end

    def receipt_info
      if @order.has_receipt?
        render json: {
          receipt_exists: true,
          receipt_url: @order.receipt_url,
          download_url: @order.receipt_download_url,
          created_at: @order.receipt.created_at,
          filename: @order.receipt.filename.to_s,
        }
      else
        render json: {
          receipt_exists: false,
          message: "No receipt generated for this order",
        }
      end
    rescue => e
      Rails.logger.error "Error fetching receipt info for order ID #{params[:id]}: #{e.message}"
    end

    private

    def set_order
      @order = Order.find_by(id: params[:id])
      render json: { error: "Order not found" }, status: :not_found unless @order
    end

    def authorize_order_access
      unless @order.user_id == current_user.id || current_user.admin?
        render json: { error: "Not authorized" }, status: :forbidden
      end
    end

    def filter_by_status(orders)
      return orders unless params[:status].present?

      case params[:status].downcase
      when "all"
        orders
      when "pending"
        orders.where(status: "pending")
      when "confirmed"
        orders.where(status: "confirmed")
      when "preparing"
        orders.where(status: "preparing")
      when "out_for_delivery"
        orders.where(status: "out_for_delivery")
      when "delivered"
        orders.where(status: "delivered")
      when "cancelled"
        orders.where(status: "cancelled")
      else
        orders
      end
    end

    def filter_by_date_range(orders)
      return orders unless params[:date_range].present?

      case params[:date_range].downcase
      when "30d"
        orders.where("created_at >= ?", 30.days.ago)
      when "6m"
        orders.where("created_at >= ?", 6.months.ago)
      when "1y"
        orders.where("created_at >= ?", 1.year.ago)
      else
        orders
      end
    end

    def search_by_order_id(orders)
      return orders unless params[:search].present?
      orders.where("id::text LIKE ?", "%#{params[:search]}%")
    end

    def order_includes
      {
        order_items: {
          include: {
            product: {
              only: [:id, :name, :description, :category],
            },
          },
          methods: [:item_total],
        },
        shipping_address: {
          only: [:id, :street_address, :location, :recipient_name, :recipient_phone],
        },
        billing_address: {
          only: [:id, :street_address, :location, :recipient_name, :recipient_phone],
        },
      }
    end
  end
end
