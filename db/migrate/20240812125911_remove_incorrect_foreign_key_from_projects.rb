class RemoveIncorrectForeignKeyFromProjects < ActiveRecord::Migration[7.0]
  def change
    # Replace 'fk_rails_3549273dc2' with the actual constraint name if different
    remove_foreign_key :projects, column: :project_manager_id
  end
end
