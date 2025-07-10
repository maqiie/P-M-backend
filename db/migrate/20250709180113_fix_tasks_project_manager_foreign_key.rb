class FixTasksProjectManagerForeignKey < ActiveRecord::Migration[7.0]
  def change
    # Remove the incorrect foreign key constraint to project_managers table
    remove_foreign_key :tasks, :project_managers if foreign_key_exists?(:tasks, :project_managers)
    
    # Add the correct foreign key constraint to users table
    add_foreign_key :tasks, :users, column: :project_manager_id unless foreign_key_exists?(:tasks, :users, column: :project_manager_id)
  end
end