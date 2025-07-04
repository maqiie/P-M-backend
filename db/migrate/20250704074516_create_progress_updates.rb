class CreateProgressUpdates < ActiveRecord::Migration[7.0]
  def change
    create_table :progress_updates do |t|
      # Foreign key to projects
      t.references :project, null: false, foreign_key: true, index: true
      
      # Progress tracking
      t.decimal :old_progress, precision: 5, scale: 2, null: false
      t.decimal :new_progress, precision: 5, scale: 2, null: false
      
      # Update details
      t.text :notes
      t.string :update_type, default: 'manual' # manual, automatic, milestone
      
      # Who made the update (optional for automatic updates)
      t.references :updated_by, null: true, foreign_key: { to_table: :users }
      
      # Additional metadata
      t.decimal :timeline_progress_at_update, precision: 5, scale: 2
      t.decimal :variance_at_update, precision: 5, scale: 2
      t.string :project_status_at_update
      
      t.timestamps
    end
    
    # Composite indexes for better query performance
    add_index :progress_updates, [:project_id, :created_at], name: 'index_progress_updates_on_project_and_date'
    add_index :progress_updates, [:updated_by_id, :created_at], name: 'index_progress_updates_on_user_and_date'
    add_index :progress_updates, :update_type
    
    # Constraints to ensure progress values are valid
    add_check_constraint :progress_updates, 'old_progress >= 0 AND old_progress <= 100', name: 'old_progress_range'
    add_check_constraint :progress_updates, 'new_progress >= 0 AND new_progress <= 100', name: 'new_progress_range'
  end
end