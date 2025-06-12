class Product < ApplicationRecord
  has_many :product_variants
  has_many :cart_items
  has_many :order_items
  has_one_attached :image # This is the crucial line for Active Storage
end
