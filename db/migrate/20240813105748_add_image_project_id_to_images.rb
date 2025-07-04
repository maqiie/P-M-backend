class AddImageProjectIdToImages < ActiveRecord::Migration[6.1]
  def change
    add_reference :images, :image_project, null: true, foreign_key: true
  end
end
