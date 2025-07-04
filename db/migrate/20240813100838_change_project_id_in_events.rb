class ChangeProjectIdInEvents < ActiveRecord::Migration[7.0]
  def change
    change_column_null :events, :project_id, true
  end
end
