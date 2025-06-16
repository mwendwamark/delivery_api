class ProductVariantSerializer < ActiveModel::Serializer
  attributes :id, :product_id, :size, :price, :availability, :stock, 
             :created_at, :updated_at
end 