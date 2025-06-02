class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :size
      t.integer :quantity
      t.integer :price_per_unit

      t.timestamps
    end
  end
end
