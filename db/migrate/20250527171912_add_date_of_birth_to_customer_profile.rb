class AddDateOfBirthToCustomerProfile < ActiveRecord::Migration[8.0]
  def change
    add_column :customer_profiles, :date_of_birth, :date
    add_index :customer_profiles, :date_of_birth
  end
end
