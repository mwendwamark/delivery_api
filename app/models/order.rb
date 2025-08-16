class Order < ApplicationRecord
  belongs_to :user
  belongs_to :address
  has_many :order_items, dependent: :destroy # Add dependent: :destroy to clean up items when order is deleted
  has_one :payment # You can keep this, but the primary payment info will be on Order itself now.

  # If you want to use Active Storage for PDF receipts:
  # has_one_attached :receipt_pdf

  # Add validations if needed, e.g., presence of total_price, status
  validates :total_price, presence: true, numericality: { greater_than: 0 }
  validates :payment_status, presence: true
  validates :status, presence: true
end