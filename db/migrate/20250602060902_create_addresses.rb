class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :location
      t.string :street_address
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
