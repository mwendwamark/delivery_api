class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.string :method
      t.string :status
      t.string :transaction_code
      t.references :order, null: false, foreign_key: true

      t.timestamps
    end
  end
end
