class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :address, null: false, foreign_key: true
      t.integer :total_price
      t.string :status
      t.text :delivery_instructions

      t.timestamps
    end
  end
end
