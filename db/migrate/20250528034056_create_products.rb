class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.string :category
      t.string :subcategory
      t.string :brand
      t.string :country
      t.float :abv
      t.text :description
      t.string :image_url

      t.timestamps
    end
  end
end
