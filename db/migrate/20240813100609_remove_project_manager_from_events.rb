class RemoveProjectManagerFromEvents < ActiveRecord::Migration[7.0]
  def change
    remove_reference :events, :project_manager, foreign_key: true
  end
end
