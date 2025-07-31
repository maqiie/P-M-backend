class CreateActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :activities do |t|
      t.references :actor, polymorphic: true, null: false
      t.string :action
      t.references :target, polymorphic: true, null: false
      t.jsonb :metadata

      t.timestamps
    end
  end
end
