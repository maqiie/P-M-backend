class AddCorrectForeignKeyToProjects < ActiveRecord::Migration[7.0]
  def change
    # Add a foreign key constraint that references the users table
    add_foreign_key :projects, :users, column: :project_manager_id
  end
end
