class AddDetailsToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :location, :string
    add_column :projects, :finishing_date, :date
    add_column :projects, :lead_person, :string
    add_column :projects, :responsible, :string
  end
end
