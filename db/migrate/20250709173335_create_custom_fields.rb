class CreateCustomFields < ActiveRecord::Migration[7.0]
  def change
    create_table :custom_fields do |t|
      t.string :name, null: false
      t.string :field_type, null: false
      t.text :description
      t.boolean :required, default: false
      t.string :entity_type, default: 'task'
      t.json :options, default: {}

      t.timestamps
    end

    add_index :custom_fields, [:entity_type, :name], unique: true
    add_index :custom_fields, :field_type
  end
end