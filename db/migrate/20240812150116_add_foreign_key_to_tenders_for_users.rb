class AddForeignKeyToTendersForUsers < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :tenders, :users, column: :project_manager_id
  end
end
