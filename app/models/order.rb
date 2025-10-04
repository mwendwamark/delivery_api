# app/models/order.rb
class Order < ApplicationRecord
  belongs_to :user
  belongs_to :shipping_address, class_name: 'Address', foreign_key: 'shipping_address_id'
  belongs_to :billing_address, class_name: 'Address', foreign_key: 'billing_address_id', optional: true
  has_many :order_items, dependent: :destroy
  has_one :payment
  has_one_attached :receipt

  validates :total_price, presence: true, numericality: { greater_than: 0 }
  validates :payment_status, presence: true
  validates :status, presence: true

  def generate_and_store_receipt
    if ReceiptGeneratorService.new(self).generate_pdf_and_attach
      receipt_url
    else
      Rails.logger.error "Failed to generate receipt for order #{id}"
      nil
    end
  end

  def receipt_url
    return nil unless receipt.attached?
    # Use rails_blob_url to generate a presigned S3 URL
    Rails.application.routes.url_helpers.rails_blob_url(receipt, disposition: "attachment")
  end

  def receipt_download_url(expires_in: 1.hour)
    return nil unless receipt.attached?
    # Use Active Storage's service_url for a presigned, expiring URL
    receipt.service_url(expires_in: expires_in, disposition: "attachment")
  end

  def has_receipt?
    receipt.attached?
  end
end