class Project < ApplicationRecord
  # Associations
  belongs_to :project_manager, class_name: 'User', foreign_key: 'project_manager_id'
  belongs_to :supervisor, class_name: 'User', foreign_key: 'supervisor_id'
  has_many :events, dependent: :destroy
  has_many :tenders, dependent: :destroy
  has_many :progress_updates, dependent: :destroy

  belongs_to :site_manager, class_name: 'User', foreign_key: 'site_manager_id', optional: true
  belongs_to :user, optional: true

  # Enums for status
  enum status: {
    planning: 0,
    in_progress: 1,
    review: 2,
    on_hold: 3,
    completed: 4,
    cancelled: 5,
    at_risk: 6
  }
  
  enum priority: {
    low: 0,
    medium: 1,
    high: 2, 
    critical: 3
  }

  # Validations
  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :status, presence: true
  validates :project_manager_id, presence: true
  validates :supervisor_id, presence: true
  validates :finishing_date, presence: true
  validate :finishing_date_cannot_be_in_the_past

  # Scopes
  scope :active, -> { where.not(status: ['completed', 'cancelled']) }
  scope :completed, -> { where(status: 'completed') }
  scope :overdue, -> { where('finishing_date < ? AND status != ?', Date.current, 'completed') }
  scope :upcoming_deadline, ->(days = 7) { where(finishing_date: Date.current..(Date.current + days.days)) }
  scope :by_priority, -> { order(:finishing_date) }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.for_project_manager(user_id)
    where(project_manager_id: user_id)
  end

  def self.for_supervisor(user_id)
    where(supervisor_id: user_id)
  end

  def self.by_status_count
    group(:status).count
  end

  def self.completion_rate
    total = count
    return 0 if total.zero?
    completed_count = completed.count
    (completed_count.to_f / total * 100).round(1)
  end

  # UPDATED: Progress tracking methods
  def progress_percentage
    val = self[:progress_percentage]
    return calculate_progress_from_status if val.nil?
    val.to_f.round(2)
  end
  

  def calculate_progress_from_status
    case status
    when 'planning' then 15
    when 'in_progress' then 50
    when 'review' then 85
    when 'completed' then 100
    when 'on_hold' then 25
    else 0
    end
  end

  # NEW: Timeline progress calculation
  def timeline_progress_percentage
    return 0.0 unless start_date && finishing_date
    return 100.0 if Date.current >= finishing_date
    
    total_days = (finishing_date - start_date).to_i
    return 0.0 if total_days <= 0
    
    elapsed_days = (Date.current - start_date).to_i
    return 0.0 if elapsed_days <= 0
    
    ((elapsed_days.to_f / total_days) * 100).round(2)
  end

  # NEW: Progress variance calculation
  def progress_variance
    timeline_progress = timeline_progress_percentage
    current_progress = progress_percentage
    (current_progress - timeline_progress).round(2)
  end

  # NEW: Schedule status determination
  def schedule_status
    variance = progress_variance
    
    case variance
    when -Float::INFINITY..-10.0
      'significantly_behind'
    when -10.0..-5.0
      'behind_schedule'
    when -5.0..5.0
      'on_track'
    when 5.0..10.0
      'ahead_of_schedule'
    else
      'significantly_ahead'
    end
  end

  # NEW: Helper methods for schedule status
  def behind_schedule?
    progress_variance < -5.0
  end

  def ahead_of_schedule?
    progress_variance > 5.0
  end

  # NEW: Estimated completion date
  def estimated_completion_date
    return finishing_date if progress_percentage >= 100
    return nil unless start_date && progress_percentage > 0
    
    total_days = (finishing_date - start_date).to_i
    elapsed_days = (Date.current - start_date).to_i
    
    if progress_percentage > 0
      estimated_total_days = (elapsed_days.to_f / progress_percentage * 100).round
      start_date + estimated_total_days.days
    else
      finishing_date
    end
  end

  # Existing methods (keep these as they are)
  def overdue?
    finishing_date < Date.current && !completed?
  end

  def urgent?
    return false if completed?
    finishing_date <= 1.week.from_now
  end

  def days_remaining
    return 0 if completed? || overdue?
    (finishing_date - Date.current).to_i
  end

  def status_color
    case status
    when 'planning' then 'yellow'
    when 'in_progress' then 'blue'
    when 'review' then 'purple'
    when 'completed' then 'green'
    when 'on_hold' then 'orange'
    when 'cancelled' then 'red'
    else 'gray'
    end
  end

  def priority_level
    return 'high' if urgent? || overdue?
    return 'medium' if days_remaining <= 30
    'low'
  end

  def team_size
    # Mock calculation - replace with actual team member logic
    case status
    when 'planning' then rand(3..6)
    when 'in_progress' then rand(6..15)
    when 'review' then rand(3..8)
    else rand(1..5)
    end
  end

  def budget_utilization
    # Mock calculation - replace with actual budget logic
    case status
    when 'planning' then rand(5..20)
    when 'in_progress' then rand(30..75)
    when 'review' then rand(75..90)
    when 'completed' then rand(85..100)
    else 0
    end
  end

  def next_milestone
    events.where('date > ?', Date.current).order(:date).first
  end

  def recent_activity
    events.where(created_at: 1.week.ago..Time.current)
          .order(created_at: :desc)
          .limit(5)
  end

  private

  def finishing_date_cannot_be_in_the_past
    if finishing_date.present? && finishing_date < Date.current
      errors.add(:finishing_date, "can't be in the past")
    end
  end
end
