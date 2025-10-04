class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  # Calculate total price for this order item (price_per_unit * quantity)
  def item_total
    (price_per_unit || 0) * (quantity || 1)
  end
end
