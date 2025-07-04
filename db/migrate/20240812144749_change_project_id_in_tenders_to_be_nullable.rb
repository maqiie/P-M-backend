class ChangeProjectIdInTendersToBeNullable < ActiveRecord::Migration[6.0]
  def change
    change_column_null :tenders, :project_id, true
  end
end
