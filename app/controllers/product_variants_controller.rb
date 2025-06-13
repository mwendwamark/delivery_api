class ProductVariantsController < ApplicationController
  before_action :set_product_variant, only: [:show, :update, :destroy]
  before_action :set_product, only: [:index, :create]
  before_action :authorize_admin

  # GET /products/:product_id/product_variants
  def index
    @product_variants = @product.product_variants
    render json: @product_variants
  end

  # GET /product_variants/:id
  def show
    render json: @product_variant
  end

  # POST /products/:product_id/product_variants
  def create
    @product_variant = @product.product_variants.new(product_variant_params)

    if @product_variant.save
      render json: @product_variant, status: :created
    else
      render json: { errors: @product_variant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /product_variants/:id
  def update
    if @product_variant.update(product_variant_params)
      render json: @product_variant
    else
      render json: { errors: @product_variant.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /product_variants/:id
  def destroy
    @product_variant.destroy
    head :no_content
  end

  private

  def set_product_variant
    @product_variant = ProductVariant.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Product variant not found' }, status: :not_found
  end

  def set_product
    @product = Product.find(params[:product_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Product not found' }, status: :not_found
  end

  def product_variant_params
    params.require(:product_variant).permit(:size, :price, :availability, :stock)
  end

  def authorize_admin
    unless current_user&.admin?
      render json: { error: 'Unauthorized. Admin access required.' }, status: :forbidden
    end
  end
end