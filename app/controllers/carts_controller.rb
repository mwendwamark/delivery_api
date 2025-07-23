class CartsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cart, only: [:show, :add_item, :remove_item, :update_item]
  before_action :set_product, only: [:add_item, :remove_item, :update_item]

  def show
    render json: @cart, include: :cart_items
  end

  def add_item
    cart_item = @cart.cart_items.find_by(product_id: @product.id)
    if cart_item
      cart_item.quantity += 1
    else
      cart_item = @cart.cart_items.build(product_id: @product.id)
    end

    if cart_item.save
      render json: @cart, include: :cart_items, status: :created
    else
      render json: cart_item.errors, status: :unprocessable_entity
    end
  end

  def remove_item
    cart_item = @cart.cart_items.find_by(product_id: @product.id)
    if cart_item
      cart_item.destroy
      render json: @cart, include: :cart_items
    else
      render json: { error: "Item not found in cart" }, status: :not_found
    end
  end

  def update_item
    cart_item = @cart.cart_items.find_by(product_id: @product.id)
    if cart_item
      if cart_item.update(cart_item_params)
        render json: @cart, include: :cart_items
      else
        render json: cart_item.errors, status: :unprocessable_entity
      end
    else
      render json: { error: "Item not found in cart" }, status: :not_found
    end
  end

  private

  def set_cart
    @cart = current_user.cart || current_user.create_cart
  end

  def set_product
    @product = Product.find(params[:product_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product not found" }, status: :not_found
  end

  def cart_item_params
    params.require(:cart_item).permit(:quantity)
  end
end
