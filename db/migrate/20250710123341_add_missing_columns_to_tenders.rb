class AddMissingColumnsToTenders < ActiveRecord::Migration[7.0]
  def change
    # Add status column if it doesn't exist
    add_column :tenders, :status, :string, default: 'draft' unless column_exists?(:tenders, :status)
    
    # Add priority column if it doesn't exist  
    add_column :tenders, :priority, :string, default: 'medium' unless column_exists?(:tenders, :priority)
    
    # Add category column if it doesn't exist
    add_column :tenders, :category, :string unless column_exists?(:tenders, :category)
    
    # Add location column if it doesn't exist
    add_column :tenders, :location, :string unless column_exists?(:tenders, :location)
    
    # Add client column if it doesn't exist
    add_column :tenders, :client, :string unless column_exists?(:tenders, :client)
    
    # Add budget_estimate column if it doesn't exist
    add_column :tenders, :budget_estimate, :decimal, precision: 12, scale: 2 unless column_exists?(:tenders, :budget_estimate)
    
    # Add estimated_duration column if it doesn't exist
    add_column :tenders, :estimated_duration, :string unless column_exists?(:tenders, :estimated_duration)
    
    # Add requirements column if it doesn't exist (stored as JSON text)
    add_column :tenders, :requirements, :text unless column_exists?(:tenders, :requirements)
    
    # Add submission_count column if it doesn't exist
    add_column :tenders, :submission_count, :integer, default: 0 unless column_exists?(:tenders, :submission_count)
    
    # Add indexes for better performance
    add_index :tenders, :status unless index_exists?(:tenders, :status)
    add_index :tenders, :priority unless index_exists?(:tenders, :priority)
    add_index :tenders, :deadline unless index_exists?(:tenders, :deadline)
  end
end