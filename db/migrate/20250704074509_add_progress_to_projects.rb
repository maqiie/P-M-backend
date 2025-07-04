class AddProgressToProjects < ActiveRecord::Migration[7.0]
  def change
    # Progress tracking fields
    add_column :projects, :progress_percentage, :decimal, precision: 5, scale: 2, default: 0.0, null: false
    add_column :projects, :start_date, :date
    add_column :projects, :budget, :decimal, precision: 15, scale: 2
    add_column :projects, :description, :text
    
    # Priority enum field (0: low, 1: medium, 2: high, 3: critical)
    add_column :projects, :priority, :integer, default: 1, null: false
    
    # Timeline tracking
    add_column :projects, :actual_start_date, :date
    add_column :projects, :estimated_completion_date, :date
    add_column :projects, :last_progress_update, :datetime
    add_column :projects, :progress_notes, :text
    
    # Performance indexes
    add_index :projects, :progress_percentage
    add_index :projects, :start_date
    add_index :projects, :status
    add_index :projects, :priority
    add_index :projects, :actual_start_date
    add_index :projects, :last_progress_update
    
    # Add constraint to ensure progress is between 0 and 100
    add_check_constraint :projects, 'progress_percentage >= 0 AND progress_percentage <= 100', name: 'progress_percentage_range'
  end
end
