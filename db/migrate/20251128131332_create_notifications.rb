

class CreateNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :notifications do |t|
      # Core relationships
      t.references :user, null: false, foreign_key: true
      t.references :sender, foreign_key: { to_table: :users }
      t.references :project, foreign_key: true
      t.references :tender, foreign_key: true
      t.references :task, foreign_key: true

      # Notification content
      t.string :title, null: false
      t.text :message, null: false
      t.string :notification_type, default: 'info' # info, success, warning, urgent, error
      t.string :category, default: 'system' # system, project, tender, task, deadline, budget, safety, etc.
      t.string :priority, default: 'medium' # low, medium, high
      
      # Status tracking
      t.boolean :is_read, default: false
      t.datetime :read_at
      t.boolean :action_required, default: false
      t.boolean :archived, default: false
      
      # Additional info
      t.string :sender_name
      t.string :action_url
      t.jsonb :metadata, default: {}
      t.jsonb :tags, default: []
      
      # Expiration
      t.datetime :expires_at

      t.timestamps
    end

    # Indexes for performance
    add_index :notifications, :notification_type
    add_index :notifications, :category
    add_index :notifications, :is_read
    add_index :notifications, :priority
    add_index :notifications, [:user_id, :is_read]
    add_index :notifications, [:user_id, :created_at]
    add_index :notifications, [:user_id, :category]
    add_index :notifications, :created_at
  end
end