class MakeImageProjectIdNotNull < ActiveRecord::Migration[6.1]
  def change
    change_column_null :images, :image_project_id, false
  end
end
