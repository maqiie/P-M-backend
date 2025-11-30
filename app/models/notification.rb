# app/models/notification.rb

class Notification < ApplicationRecord
  # ============================================================================
  # ASSOCIATIONS
  # ============================================================================
  
  belongs_to :user
  belongs_to :sender, class_name: 'User', optional: true
  belongs_to :project, optional: true
  belongs_to :tender, optional: true
  belongs_to :task, optional: true

  # ============================================================================
  # VALIDATIONS
  # ============================================================================
  
  validates :title, presence: true
  validates :message, presence: true
  validates :notification_type, inclusion: { 
    in: %w[info success warning urgent error],
    message: "%{value} is not a valid notification type"
  }
  validates :category, inclusion: { 
    in: %w[system project tender task deadline budget safety meeting approval training weather equipment delivery],
    message: "%{value} is not a valid category"
  }
  validates :priority, inclusion: { 
    in: %w[low medium high],
    message: "%{value} is not a valid priority"
  }

  # ============================================================================
  # SCOPES
  # ============================================================================
  
  # Status scopes
  scope :unread, -> { where(is_read: false) }
  scope :read, -> { where(is_read: true) }
  scope :archived, -> { where(archived: true) }
  scope :active, -> { where(archived: false) }
  scope :action_required, -> { where(action_required: true, is_read: false) }
  
  # Type scopes
  scope :urgent, -> { where(notification_type: 'urgent') }
  scope :warnings, -> { where(notification_type: 'warning') }
  scope :info, -> { where(notification_type: 'info') }
  scope :success, -> { where(notification_type: 'success') }
  scope :errors, -> { where(notification_type: 'error') }
  
  # Priority scopes
  scope :high_priority, -> { where(priority: 'high') }
  scope :medium_priority, -> { where(priority: 'medium') }
  scope :low_priority, -> { where(priority: 'low') }
  
  # Category scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :project_notifications, -> { where(category: 'project') }
  scope :tender_notifications, -> { where(category: 'tender') }
  scope :task_notifications, -> { where(category: 'task') }
  scope :deadline_notifications, -> { where(category: 'deadline') }
  scope :system_notifications, -> { where(category: 'system') }
  
  # Time scopes
  scope :today, -> { where('created_at >= ?', Date.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', 1.week.ago) }
  scope :this_month, -> { where('created_at >= ?', 1.month.ago) }
  scope :recent, -> { order(created_at: :desc) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  
  # Ordering
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END")) }
  scope :by_type, -> { order(Arel.sql("CASE notification_type WHEN 'urgent' THEN 1 WHEN 'error' THEN 2 WHEN 'warning' THEN 3 WHEN 'success' THEN 4 WHEN 'info' THEN 5 END")) }

  # ============================================================================
  # CLASS METHODS
  # ============================================================================
  
  # Apply filters from params
  def self.apply_filters(params)
    notifications = all
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      notifications = notifications.where(
        'title ILIKE ? OR message ILIKE ?', 
        search_term, search_term
      )
    end
    
    if params[:notification_type].present?
      notifications = notifications.where(notification_type: params[:notification_type])
    end
    
    if params[:category].present?
      notifications = notifications.where(category: params[:category])
    end
    
    if params[:status].present?
      case params[:status]
      when 'unread'
        notifications = notifications.unread
      when 'read'
        notifications = notifications.read
      when 'action_required'
        notifications = notifications.action_required
      when 'archived'
        notifications = notifications.archived
      end
    else
      notifications = notifications.active
    end
    
    # Sorting
    sort_by = params[:sort_by] || 'created_at'
    sort_direction = params[:sort_direction] || 'desc'
    
    case sort_by
    when 'priority'
      notifications = notifications.by_priority
    when 'type'
      notifications = notifications.by_type
    else
      notifications = notifications.order(sort_by => sort_direction)
    end
    
    notifications
  end

  # ============================================================================
  # INSTANCE METHODS
  # ============================================================================
  
  def mark_as_read!
    update!(is_read: true, read_at: Time.current)
  end

  def mark_as_unread!
    update!(is_read: false, read_at: nil)
  end

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def urgent?
    notification_type == 'urgent' || priority == 'high'
  end

  def related_users
    users = []
    users << sender if sender
    users << project&.project_manager if project&.project_manager
    users << project&.supervisor if project&.supervisor
    users.compact.uniq
  end

  # Get appropriate icon for frontend
  def icon
    case category
    when 'project' then 'folder'
    when 'tender' then 'file-text'
    when 'task' then 'check-square'
    when 'deadline' then 'clock'
    when 'budget' then 'dollar-sign'
    when 'safety' then 'shield'
    when 'meeting' then 'users'
    when 'approval' then 'thumbs-up'
    when 'equipment' then 'tool'
    when 'delivery' then 'truck'
    else 'bell'
    end
  end

  # Get color based on type
  def color
    case notification_type
    when 'urgent' then 'red'
    when 'error' then 'red'
    when 'warning' then 'yellow'
    when 'success' then 'green'
    else 'blue'
    end
  end
end