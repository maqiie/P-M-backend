class AddPerformanceIndexesToProjects < ActiveRecord::Migration[7.0]
  def change
    # Add indexes if they don't already exist
    add_index :projects, :finishing_date unless index_exists?(:projects, :finishing_date)
    add_index :projects, :created_at unless index_exists?(:projects, :created_at)
    add_index :projects, :updated_at unless index_exists?(:projects, :updated_at)
    add_index :projects, [:status, :priority], name: 'index_projects_on_status_and_priority'
    add_index :projects, [:project_manager_id, :status], name: 'index_projects_on_manager_and_status'
    add_index :projects, [:supervisor_id, :status], name: 'index_projects_on_supervisor_and_status'
  end
end