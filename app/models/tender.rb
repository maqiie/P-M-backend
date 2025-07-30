class Tender < ApplicationRecord
  # Associations
  belongs_to :project_manager, class_name: 'User', foreign_key: 'project_manager_id'
  belongs_to :project, optional: true
  belongs_to :user

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :description, presence: true
  validates :deadline, presence: true
  validates :responsible, presence: true
  validate :deadline_cannot_be_in_the_past

  # Serialize requirements as JSON if using text field
  serialize :requirements, Array

  # Enums for status and priority
  enum status: {
    draft: 'draft',
    active: 'active', 
    in_review: 'in_review',
    converted: 'converted',
    completed: 'completed',
    rejected: 'rejected',
    cancelled: 'cancelled'
  }, _default: 'draft'

  enum priority: {
    low: 'low',
    medium: 'medium', 
    high: 'high',
    urgent: 'urgent'
  }, _default: 'medium'

  # Scopes
  scope :active, -> { where('deadline >= ? AND status IN (?)', Date.current, ['active', 'in_review']) }
  scope :expired, -> { where('deadline < ?', Date.current) }
  scope :urgent, ->(days = 3) { where(deadline: Date.current..(Date.current + days.days)) }
  scope :this_week, -> { where(deadline: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :by_deadline, -> { order(:deadline) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def expired?
    return false unless deadline
    deadline < Date.current
  end

  def urgent?
    return false if expired?
    deadline <= 3.days.from_now.to_date
  end

  def days_remaining
    return 0 if expired?
    (deadline - Date.current).to_i
  end

  def status_display
    return 'expired' if expired?
    return 'urgent' if urgent?
    return 'due_soon' if days_remaining <= 7
    status
  end

  def status_color
    case status_display
    when 'expired' then 'red'
    when 'urgent' then 'orange'  
    when 'due_soon' then 'yellow'
    when 'active' then 'green'
    when 'draft' then 'gray'
    when 'completed' then 'blue'
    when 'rejected' then 'red'
    else 'gray'
    end
  end

  # Default values for optional fields
  def category
    super || 'General'
  end

  def location  
    super || 'TBD'
  end

  def client
    super || 'Internal'
  end

  def budget_estimate
    super || 0
  end

  def estimated_duration
    super || 'TBD'
  end

  def requirements
    super || []
  end

  def submission_count
    super || 0
  end

  private

  def deadline_cannot_be_in_the_past
    if deadline.present? && deadline < Date.current
      errors.add(:deadline, "can't be in the past")
    end
  end
end