# class ProductsController < ApplicationController
#   # before_action :authenticate_user!
#   # include JwtAuthentication

#   before_action :set_product, only: [:show, :update, :destroy]
#   before_action :authorize_admin, except: [:create,:index, :show]

#   def index
#     @products = Product.all
#     render json: @products
#   end

#   def show
#     render json: @product
#   end

#   def create
#     @product = Product.new(product_params)

#     if @product.save
#       render json: @product, status: :created
#     else
#       render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
#     end
#   end

#   def update
#     if @product.update(product_params)
#       render json: @product
#     else
#       render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
#     end
#   end

#   def destroy
#     @product.destroy
#     head :no_content
#   end

#   private

#   def set_product
#     @product = Product.find(params[:id])
#   rescue ActiveRecord::RecordNotFound
#     render json: { error: 'Product not found' }, status: :not_found
#   end

#   def product_params
#     params.require(:product).permit(
#       :name,
#       :category,
#       :subcategory,
#       :brand,
#       :country,
#       :abv,
#       :description,
#       :image_url
#     )
#   end

#   def authorize_admin
#     unless current_user.admin?
#       render json: { error: 'Unauthorized. Admin access required.' }, status: :forbidden
#     end
#   end
# end 

class ProductsController < ApplicationController
  # include JwtAuthentication
  
  # Include Rails URL helpers to generate Active Storage URLs
  # This is needed because you're generating URLs in the controller directly
  include Rails.application.routes.url_helpers

  before_action :set_product, only: [:show, :update, :destroy]
  before_action :authorize_admin, except: [:create,:index, :show]

  def index
    @products = Product.all
    # When rendering products, map them to include the image URL
    render json: @products.map { |product| product_with_image_url(product) }
  end

  def show
    render json: product_with_image_url(@product)
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      # Render the product with its newly attached image URL
      render json: product_with_image_url(@product), status: :created
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      render json: product_with_image_url(@product)
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    head :no_content
  end

  private

  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Product not found' }, status: :not_found
  end

  def product_params
    params.require(:product).permit(
      :name,
      :category,
      :subcategory,
      :brand,
      :country,
      :abv,
      :description,
      :image # <--- CRUCIAL: Permit the :image attachment, NOT :image_url
    )
  end

  def authorize_admin
    # Ensure current_user is available and has an admin? method
    # You might need to authenticate_user! before authorize_admin
    unless current_user&.admin? # Use & for safe navigation
      render json: { error: 'Unauthorized. Admin access required.' }, status: :forbidden
    end
  end

  # Helper method to include the image URL in the JSON response
  def product_with_image_url(product)
    product.as_json.tap do |hash|
      if product.image.attached?
        # url_for generates a full URL including host/port for the image
        hash[:image_url] = url_for(product.image) 
      else
        hash[:image_url] = nil # Or a default placeholder image URL
      end
    end
  end
end