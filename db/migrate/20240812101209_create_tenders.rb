class CreateTenders < ActiveRecord::Migration[6.0]
  def change
    create_table :tenders do |t|
      t.string :title
      t.text :description
      t.date :deadline
      t.string :lead_person
      t.string :responsible
      t.references :project_manager, foreign_key: true
      t.references :project, foreign_key: true

      t.timestamps
    end
  end
end
