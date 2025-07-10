class CreateTaskAssigneesAndWatchers < ActiveRecord::Migration[7.0]
  def change
    # Create join table for task assignees
    create_join_table :tasks, :users, table_name: :task_assignees do |t|
      t.index :task_id
      t.index :user_id
    end
    
    # Create join table for task watchers
    create_join_table :tasks, :users, table_name: :task_watchers do |t|
      t.index :task_id
      t.index :user_id
    end
  end
end