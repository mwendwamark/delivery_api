class Order < ApplicationRecord
  belongs_to :user
  belongs_to :address
  has_many :order_items
  has_one :payment
end
