class CreateEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :events do |t|
      t.text :description
      t.datetime :date
      t.references :project, null: false, foreign_key: true
      t.references :project_manager, null: false, foreign_key: true

      t.timestamps
    end
  end
end
