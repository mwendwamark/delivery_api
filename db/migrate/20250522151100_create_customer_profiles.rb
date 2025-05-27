class CreateCustomerProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address
      t.string :preferred_payment_method
      t.text :delivery_instructions
      t.boolean :is_verified, default: false

      t.timestamps
    end
  end
end 