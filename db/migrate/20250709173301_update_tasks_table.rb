class UpdateTasksTable < ActiveRecord::Migration[7.0]
  def change
    # Add missing columns to the existing tasks table
    add_column :tasks, :start_date, :date
    add_column :tasks, :priority, :string, default: 'medium'
    add_column :tasks, :estimated_hours, :decimal, precision: 8, scale: 2
    add_column :tasks, :project_id, :bigint
    add_column :tasks, :custom_fields, :json, default: {}
    add_column :tasks, :tags, :json, default: []
    add_column :tasks, :is_starred, :boolean, default: false
    add_column :tasks, :is_archived, :boolean, default: false
    add_column :tasks, :user_id, :bigint
    
    # Add foreign key for project_id
    add_foreign_key :tasks, :projects, column: :project_id
    add_foreign_key :tasks, :users, column: :user_id
    
    # Add indexes for better performance
    add_index :tasks, :priority
    add_index :tasks, :due_date
    add_index :tasks, :project_id
    add_index :tasks, :user_id
    add_index :tasks, [:project_manager_id, :status]
    
    # Convert status from integer to string if needed
    # You might need to adjust this based on your current enum values
    # For now, let's add a string column for the API compatibility
    add_column :tasks, :status_string, :string, default: 'pending'
  end
end