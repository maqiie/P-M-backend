# db/migrate/XXXXXX_create_meetings.rb
class CreateMeetings < ActiveRecord::Migration[7.0]
  def change
    create_table :meetings do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :meeting_date, null: false
      t.string :location
      t.string :meeting_type, default: 'in_person'
      t.string :status, default: 'scheduled'
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :project, foreign_key: true, null: true
      t.integer :duration_minutes, default: 60
      t.string :meeting_link
      t.text :notes
      t.text :agenda

      t.timestamps
    end

    create_table :meeting_participants do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'pending'
      t.boolean :is_required, default: true
      t.datetime :responded_at

      t.timestamps
    end

    add_index :meeting_participants, [:meeting_id, :user_id], unique: true
    add_index :meetings, :meeting_date
    add_index :meetings, :status
  end
end