class CreateProjectMilestones < ActiveRecord::Migration[7.0]
  def change
    create_table :project_milestones do |t|
      # Foreign key to projects
      t.references :project, null: false, foreign_key: true, index: true
      
      # Milestone details
      t.string :name, null: false
      t.text :description
      t.date :planned_date
      t.date :actual_date
      t.decimal :progress_percentage_target, precision: 5, scale: 2, default: 0.0
      
      # Status tracking
      t.integer :status, default: 0 # 0: pending, 1: in_progress, 2: completed, 3: delayed, 4: cancelled
      t.integer :order_position, default: 0
      
      # Who is responsible
      t.references :assigned_to, null: true, foreign_key: { to_table: :users }
      
      # Dependencies
      t.references :depends_on_milestone, null: true, foreign_key: { to_table: :project_milestones }
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :project_milestones, :assigned_to_id, if_not_exists: true

    add_index :project_milestones, [:project_id, :order_position], name: 'index_milestones_on_project_and_order'
    add_index :project_milestones, [:project_id, :status], name: 'index_milestones_on_project_and_status'
    add_index :project_milestones, :planned_date
    add_index :project_milestones, :actual_date
    
    # Constraint for progress percentage
    add_check_constraint :project_milestones, 'progress_percentage_target >= 0 AND progress_percentage_target <= 100', name: 'milestone_progress_range'
  end
end