class SetDefaultProgressValues < ActiveRecord::Migration[7.0]
  def up
    # Set start_date for existing projects that don't have it
    Project.where(start_date: nil).find_each do |project|
      # Use created_at as start_date for existing projects
      project.update_column(:start_date, project.created_at.to_date)
    end
    
    # Set actual_start_date for in_progress projects
    Project.where(status: 'in_progress', actual_start_date: nil).find_each do |project|
      project.update_column(:actual_start_date, project.start_date || project.created_at.to_date)
    end
    
    # Set priority for existing projects (default to medium)
    Project.where(priority: nil).update_all(priority: 1)
    
    # Set progress_percentage for completed projects
    Project.where(status: 'completed', progress_percentage: 0).update_all(progress_percentage: 100.0)
  end
  
  def down
    # Rollback is intentionally left empty since we don't want to remove data
  end
end