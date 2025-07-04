# class Tender < ApplicationRecord
#   belongs_to :project_manager, optional: true


#   # Add validations if needed
#   validates :description, presence: true
#   validates :deadline, presence: true
#   validates :title, presence: true
#   validates :title, :description, :deadline, :lead_person, presence: true
  
# end

# Tender Model Updates (app/models/tender.rb)
class Tender < ApplicationRecord
  # Associations
  belongs_to :project_manager, class_name: 'User', foreign_key: 'project_manager_id'
  belongs_to :project, optional: true

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :description, presence: true
  validates :deadline, presence: true
  validates :responsible, presence: true
  validate :deadline_cannot_be_in_the_past

  # Scopes
  scope :active, -> { where('deadline >= ?', Date.current) }
  scope :expired, -> { where('deadline < ?', Date.current) }
  scope :urgent, ->(days = 3) { where(deadline: Date.current..(Date.current + days.days)) }
  scope :this_week, -> { where(deadline: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :by_deadline, -> { order(:deadline) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def expired?
    deadline < Date.current
  end

  def urgent?
    !expired? && deadline <= 3.days.from_now
  end

  def days_remaining
    return 0 if expired?
    (deadline - Date.current).to_i
  end

  def status
    return 'expired' if expired?
    return 'urgent' if urgent?
    return 'due_soon' if days_remaining <= 7
    'active'
  end

  def status_color
    case status
    when 'expired' then 'red'
    when 'urgent' then 'orange'
    when 'due_soon' then 'yellow'
    else 'green'
    end
  end

  private

  def deadline_cannot_be_in_the_past
    if deadline.present? && deadline < Date.current
      errors.add(:deadline, "can't be in the past")
    end
  end
end
