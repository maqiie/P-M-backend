class RemoveForeignKeyFromTenders < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :tenders, :project_managers
  end
end
