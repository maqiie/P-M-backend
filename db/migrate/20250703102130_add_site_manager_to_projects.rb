class AddSiteManagerToProjects < ActiveRecord::Migration[7.0]
  def change
    add_reference :projects, :site_manager, null: true, foreign_key: true
  end
end