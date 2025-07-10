class Task < ApplicationRecord
  # Associations - both project_manager_id and user_id reference the users table
  belongs_to :project_manager, class_name: 'User', foreign_key: 'project_manager_id'
  belongs_to :user, optional: true
  belongs_to :project, optional: true
  
  # Many-to-many associations for assignees and watchers
  has_and_belongs_to_many :assignees, class_name: 'User', join_table: 'task_assignees'
  has_and_belongs_to_many :watchers, class_name: 'User', join_table: 'task_watchers'

  validates :title, presence: true
  
  # Since your existing status is an integer (enum), let's define the enum
  enum status: {
    pending: 0,
    in_progress: 1,
    in_review: 2,
    completed: 3,
    cancelled: 4,
    on_hold: 5
  }
  
  # Priority validation
  validates :priority, inclusion: { in: %w[low medium high urgent] }, allow_nil: true

  # Scopes
  scope :active, -> { where.not(status: [:completed, :cancelled]) }
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Date.current, [statuses[:completed], statuses[:cancelled]]) }
  scope :due_today, -> { where(due_date: Date.current) }

  # Helper methods
  def overdue?
    due_date.present? && due_date < Date.current && !['completed', 'cancelled'].include?(status)
  end

  def completion_percentage
    case status
    when 'completed'
      100
    when 'in_progress'
      50
    when 'in_review'
      75
    else
      0
    end
  end
  
  # Method to get the task owner (either user or project_manager)
  def owner
    user || project_manager
  end
  
  # For API compatibility - return status as string
  def status_string
    status
  end
  
  # Override as_json to include the fields the frontend expects
  def as_json(options = {})
    super(options.merge(
      methods: [:status_string],
      include: options[:include] || []
    ))
  end
end