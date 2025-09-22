# app/serializers/order_serializer.rb
class OrderSerializer < ActiveModel::Serializer
  attributes :id, :total_price, :payment_status, :status, :delivery_instructions,
             :created_at, :updated_at, :receipt_info

  belongs_to :user
  belongs_to :address
  has_many :order_items

  def receipt_info
    if object.has_receipt?
      {
        receipt_exists: true,
        receipt_url: object.receipt_url,
        download_url: object.receipt_download_url,
        filename: object.receipt.filename.to_s,
        created_at: object.receipt.created_at
      }
    else
      {
        receipt_exists: false
      }
    end
  end
end