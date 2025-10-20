class ProductsController < ApplicationController
  include Rails.application.routes.url_helpers

  skip_before_action :authenticate_request, only: [:index, :show]
  before_action :set_product, only: [:show, :update, :destroy]
  before_action :authorize_admin, except: [:index, :show]

  def index
    @products = Product.includes(:product_variants, image_attachment: :blob)

    # Search functionality
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @products = @products.where(
        "name ILIKE ? OR description ILIKE ? OR brand ILIKE ? OR category ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end

    # Category filter
    @products = @products.where(category: params[:category]) if params[:category].present?

    # Subcategory filter
    @products = @products.where(subcategory: params[:subcategory]) if params[:subcategory].present?

    # Brand filter
    @products = @products.where(brand: params[:brand]) if params[:brand].present?

    # Country filter
    @products = @products.where(country: params[:country]) if params[:country].present?

    # Price range filter (works with product variants)
    if params[:min_price].present? || params[:max_price].present?
      variant_ids = ProductVariant.all
      variant_ids = variant_ids.where("price >= ?", params[:min_price]) if params[:min_price].present?
      variant_ids = variant_ids.where("price <= ?", params[:max_price]) if params[:max_price].present?
      product_ids = variant_ids.distinct.pluck(:product_id)
      @products = @products.where(id: product_ids)
    end

    # Availability filter
    if params[:available_only] == "true"
      available_product_ids = ProductVariant.where(availability: true, stock: 1..).distinct.pluck(:product_id)
      @products = @products.where(id: available_product_ids)
    end

    # Sorting
    case params[:sort_by]
    when "name_asc"
      @products = @products.order(:name)
    when "name_desc"
      @products = @products.order(name: :desc)
    when "price_asc"
      # Sort by minimum variant price
      @products = @products.left_joins(:product_variants)
                           .group("products.id")
                           .order("MIN(product_variants.price) ASC NULLS LAST")
    when "price_desc"
      # Sort by maximum variant price
      @products = @products.left_joins(:product_variants)
                           .group("products.id")
                           .order("MAX(product_variants.price) DESC NULLS LAST")
    when "newest"
      @products = @products.order(created_at: :desc)
    else
      @products = @products.order(:name)
    end

    @products = @products.all

    # Return products with enhanced data including price info
    render json: {
      products: @products.map { |product| product_with_enhanced_data(product) },
      filters: get_filter_options,
    }
  end

  def show
    render json: product_with_enhanced_data(@product)
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      render json: product_with_enhanced_data(@product), status: :created
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      render json: product_with_enhanced_data(@product)
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
    render json: { error: "Product not found" }, status: :not_found
  end

  def product_params
    params.require(:product).permit(
      :name, :category, :subcategory, :brand, :country, :abv, :description, :image
    )
  end

  def authorize_admin
    unless current_user&.admin?
      render json: { error: "Unauthorized. Admin access required." }, status: :forbidden
    end
  end

  def product_with_enhanced_data(product)
    variants = product.product_variants.where(availability: true, stock: 1..)

    # Calculate price information
    prices = variants.pluck(:price).compact
    price_info = if prices.any?
        {
          min_price: prices.min,
          max_price: prices.max,
          price_range: prices.min == prices.max ? "#{prices.min}" : "#{prices.min} - #{prices.max}",
          has_variants: true,
        }
      else
        {
          min_price: nil,
          max_price: nil,
          price_range: "Out of stock",
          has_variants: false,
        }
      end

    # Calculate availability
    available_variants_count = variants.count
    total_stock = variants.sum(:stock)

    product.as_json(include: { product_variants: {} }).merge({
      image_url: product.image.attached? ? url_for(product.image) : nil,
      price_info: price_info,
      availability_info: {
        available_variants: available_variants_count,
        total_stock: total_stock,
        is_available: available_variants_count > 0,
      },
    })
  end

  def get_filter_options
    {
      categories: Product.distinct.pluck(:category).compact.sort,
      subcategories: Product.distinct.pluck(:subcategory).compact.sort,
      brands: Product.distinct.pluck(:brand).compact.sort,
      countries: Product.distinct.pluck(:country).compact.sort,
      price_range: {
        min: ProductVariant.minimum(:price) || 0,
        max: ProductVariant.maximum(:price) || 0,
      },
    }
  end
end
