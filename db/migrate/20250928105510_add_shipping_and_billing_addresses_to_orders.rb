class AddShippingAndBillingAddressesToOrders < ActiveRecord::Migration[8.0]
  def up
    # Rename the existing address_id to shipping_address_id
    rename_column :orders, :address_id, :shipping_address_id
    
    # Add a foreign key constraint for the shipping address
    add_foreign_key :orders, :addresses, column: :shipping_address_id
    
    # Add billing_address_id column with a foreign key
    add_reference :orders, :billing_address, foreign_key: { to_table: :addresses }
    
    # Copy shipping address to billing address for existing records
    execute 'UPDATE orders SET billing_address_id = shipping_address_id'
  end
  
  def down
    # Remove the foreign key constraints first
    remove_foreign_key :orders, column: :shipping_address_id
    remove_foreign_key :orders, column: :billing_address_id
    
    # Rename back to address_id
    rename_column :orders, :shipping_address_id, :address_id
    
    # Remove the billing_address_id column
    remove_column :orders, :billing_address_id
  end
end
