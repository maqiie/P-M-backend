# class Event < ApplicationRecord
#   belongs_to :project, optional: true

#   validates :description, presence: true
#   validates :date, presence: true
#   validates :responsible, presence: true
# end

# Event Model Updates (app/models/event.rb)
class Event < ApplicationRecord
  # Associations
  belongs_to :project

  # Validations
  validates :description, presence: true, length: { minimum: 3, maximum: 500 }
  validates :date, presence: true
  validates :responsible, presence: true
  validate :date_cannot_be_in_the_past

  # Scopes
  scope :upcoming, -> { where('date >= ?', Date.current) }
  scope :past, -> { where('date < ?', Date.current) }
  scope :this_week, -> { where(date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :next_week, -> { where(date: Date.current.next_week.beginning_of_week..Date.current.next_week.end_of_week) }
  scope :this_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :by_date, -> { order(:date) }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.for_project_manager(user_id)
    joins(:project).where(projects: { project_manager_id: user_id })
  end

  def self.urgent(days = 3)
    upcoming.where(date: Date.current..(Date.current + days.days))
  end

  def self.by_type(type)
    case type.downcase
    when 'meeting'
      where('description ILIKE ?', '%meeting%')
    when 'deadline'
      where('description ILIKE ?', '%deadline%')
    when 'review'
      where('description ILIKE ?', '%review%')
    else
      all
    end
  end

  # Instance methods
  def overdue?
    date < Date.current
  end

  def today?
    date.to_date == Date.current
  end

  def tomorrow?
    date.to_date == Date.current + 1.day
  end

  def this_week?
    date.to_date.between?(Date.current.beginning_of_week, Date.current.end_of_week)
  end

  def urgent?
    upcoming? && date <= 3.days.from_now
  end

  def upcoming?
    date >= Date.current
  end

  def days_until
    return 0 if overdue?
    (date.to_date - Date.current).to_i
  end

  def event_type
    description_lower = description.downcase
    
    case description_lower
    when /meeting|standup|kickoff|discussion/
      'meeting'
    when /deadline|delivery|submission|due/
      'deadline'
    when /review|presentation|demo|showcase/
      'review'
    when /inspection|visit|site|audit/
      'inspection'
    when /training|workshop|seminar/
      'training'
    else
      'general'
    end
  end

  def urgency_level
    return 'overdue' if overdue?
    return 'urgent' if days_until <= 1
    return 'soon' if days_until <= 3
    return 'upcoming' if days_until <= 7
    'future'
  end

  def color_class
    case urgency_level
    when 'overdue' then 'red'
    when 'urgent' then 'orange'
    when 'soon' then 'yellow'
    when 'upcoming' then 'blue'
    else 'green'
    end
  end

  def formatted_date
    if today?
      'Today'
    elsif tomorrow?
      'Tomorrow'
    elsif this_week?
      date.strftime('%A')
    else
      date.strftime('%B %d, %Y')
    end
  end

  private

  def date_cannot_be_in_the_past
    if date.present? && date < Time.current
      errors.add(:date, "can't be in the past")
    end
  end
end