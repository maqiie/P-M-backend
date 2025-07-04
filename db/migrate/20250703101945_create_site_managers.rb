class CreateSiteManagers < ActiveRecord::Migration[7.0]
  def change
    create_table :site_managers do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :location
      t.string :specialization
      t.integer :experience_years, default: 0
      t.integer :status, default: 0
      t.integer :availability, default: 0
      t.text :certifications

      t.timestamps
    end
    
    add_index :site_managers, :email, unique: true
  end
end