class ProductSerializer < ActiveModel::Serializer
  attributes :id, :name, :category, :subcategory, :brand, :country, :abv,
             :description, :created_at, :updated_at, :image_url

  has_many :product_variants

  def image_url
    return nil unless object.image.attached?
    Rails.application.routes.default_url_options[:host] = "localhost:3000"
    Rails.application.routes.url_helpers.url_for(object.image)
  end
end
