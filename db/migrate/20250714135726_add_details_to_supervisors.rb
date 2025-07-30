class AddDetailsToSupervisors < ActiveRecord::Migration[7.0]
  def change
    add_column :supervisors, :phone, :string
    add_column :supervisors, :location, :string
    add_column :supervisors, :specialization, :string
    add_column :supervisors, :experience_years, :integer
  end
end
