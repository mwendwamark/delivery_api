class CreateDeliveryPersonProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_person_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :vehicle_type
      t.string :vehicle_registration_number
      t.float :current_latitude
      t.float :current_longitude
      t.string :availability_status
      t.float :rating, default: 0.0
      t.integer :completed_deliveries_count, default: 0
      t.string :license_number
      t.string :id_document_url
      t.boolean :is_verified, default: false

      t.timestamps
    end
  end
end 