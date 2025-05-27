class CreateAdminProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :permissions
      t.boolean :is_super_admin, default: false
      t.datetime :last_activity_at
      t.string :status, default: "active"

      t.timestamps
    end
  end
end
