class AddPaystackFieldsToOrders < ActiveRecord::Migration[8.0]
  def up
    # Add payment_status if it doesn't exist
    unless column_exists?(:orders, :payment_status)
      add_column :orders, :payment_status, :string, default: 'unpaid' # e.g., 'unpaid', 'Paystack Pending', 'Paystack Paid', 'Paystack Failed', 'Cash on Delivery'
    end
    
    # Add status if it doesn't exist
    unless column_exists?(:orders, :status)
      add_column :orders, :status, :string, default: 'pending' # e.g., 'pending', 'confirmed', 'processing', 'out_for_delivery', 'delivered', 'cancelled', 'payment_failed'
    end

    # Paystack specific fields
    unless column_exists?(:orders, :paystack_reference)
      add_column :orders, :paystack_reference, :string # Unique ID from Paystack for the transaction
      add_index :orders, :paystack_reference, unique: true, if_not_exists: true # Add unique index for quick lookup
    end

    # Add remaining Paystack related columns if they don't exist
    unless column_exists?(:orders, :paystack_transaction_id)
      add_column :orders, :paystack_transaction_id, :string # Paystack's internal transaction ID
    end
    
    unless column_exists?(:orders, :paystack_status)
      add_column :orders, :paystack_status, :string # Status from Paystack (e.g., 'success', 'failed', 'abandoned')
    end
    
    unless column_exists?(:orders, :payment_method)
      add_column :orders, :payment_method, :string # e.g., 'card', 'bank_transfer', 'ussd', 'mobile_money', 'bank_transfer', 'pay_with_bank'
    end
    
    unless column_exists?(:orders, :payment_channel)
      add_column :orders, :payment_channel, :string # e.g., 'card', 'bank', 'ussd', 'qr', 'mobile_money', 'bank_transfer'
    end
    
    unless column_exists?(:orders, :payment_currency)
      add_column :orders, :payment_currency, :string, default: 'NGN' # e.g., 'NGN', 'USD', 'GHS', 'ZAR'
    end
    
    unless column_exists?(:orders, :payment_amount)
      add_column :orders, :payment_amount, :decimal, precision: 10, scale: 2 # Amount in kobo (smallest currency unit)
    end
    
    unless column_exists?(:orders, :paystack_amount)
      add_column :orders, :paystack_amount, :decimal, precision: 10, scale: 2 # Amount from Paystack (in KES)
    end
    
    unless column_exists?(:orders, :paystack_currency)
      add_column :orders, :paystack_currency, :string # Currency (e.g., 'KES')
    end
    
    unless column_exists?(:orders, :paystack_channel)
      add_column :orders, :paystack_channel, :string # Payment channel (e.g., 'mobile_money', 'card')
    end

    # For receipt URL
    unless column_exists?(:orders, :receipt_url)
      add_column :orders, :receipt_url, :string # URL to the downloadable PDF receipt
    end
  end

  def down
    # Remove all the columns if they exist
    remove_column :orders, :payment_status if column_exists?(:orders, :payment_status)
    remove_column :orders, :status if column_exists?(:orders, :status)
    remove_column :orders, :paystack_reference if column_exists?(:orders, :paystack_reference)
    remove_column :orders, :paystack_transaction_id if column_exists?(:orders, :paystack_transaction_id)
    remove_column :orders, :paystack_status if column_exists?(:orders, :paystack_status)
    remove_column :orders, :payment_method if column_exists?(:orders, :payment_method)
    remove_column :orders, :payment_channel if column_exists?(:orders, :payment_channel)
    remove_column :orders, :payment_currency if column_exists?(:orders, :payment_currency)
    remove_column :orders, :payment_amount if column_exists?(:orders, :payment_amount)
    remove_column :orders, :receipt_url if column_exists?(:orders, :receipt_url)
    
    # Remove the index if it exists
    if index_exists?(:orders, :paystack_reference)
      remove_index :orders, :paystack_reference
    end
  end
end
