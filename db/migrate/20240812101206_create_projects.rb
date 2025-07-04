# class CreateProjects < ActiveRecord::Migration[7.0]
#   def change
#     create_table :projects do |t|
#       t.string :title
#       t.integer :status
#       t.references :project_manager, null: false, foreign_key: true
#       t.references :supervisor, null: false, foreign_key: true

#       t.timestamps
#     end
#   end
# end
class CreateProjects < ActiveRecord::Migration[6.1]
  def change
    create_table :projects do |t|
      t.string :title
      t.integer :status
      t.references :project_manager, null: false, foreign_key: { to_table: :users }
      t.references :supervisor, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
