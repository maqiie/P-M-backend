# app/models/progress_update.rb
class ProgressUpdate < ApplicationRecord
    belongs_to :project
    belongs_to :updated_by, class_name: 'User'
    
    validates :old_progress, :new_progress, presence: true
    validates :old_progress, :new_progress, 
              numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validates :update_type, presence: true
    
    # Scopes for convenience
    scope :recent, -> { order(created_at: :desc) }
    scope :for_project, ->(project_id) { where(project_id: project_id) }
    scope :manual_updates, -> { where(update_type: 'manual') }
    
    # Calculate the change in progress
    def progress_change
      new_progress - old_progress
    end
    
    # Check if this was an increase or decrease
    def progress_increased?
      progress_change > 0
    end
    
    def progress_decreased?
      progress_change < 0
    end
  end