class AddFieldsToAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :addresses, :is_manual, :boolean
    add_column :addresses, :recipient_name, :string
    add_column :addresses, :recipient_phone, :string
  end
end
