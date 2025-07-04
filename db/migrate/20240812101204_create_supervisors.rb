class CreateSupervisors < ActiveRecord::Migration[6.1]
  def change
    create_table :supervisors do |t|
      t.string :name, null: false
      t.string :email, null: false, unique: true

      t.timestamps
    end

    add_index :supervisors, :email, unique: true
  end
end
