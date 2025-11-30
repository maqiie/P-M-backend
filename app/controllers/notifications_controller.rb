# app/controllers/notifications_controller.rb

class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:show, :mark_read, :mark_unread, :archive, :destroy]

  # GET /notifications
  def index
    @notifications = current_user.notifications
                                 .active
                                 .includes(:project, :tender, :task, :sender)
                                 .apply_filters(filter_params)

    # Pagination
    page = params[:page] || 1
    per_page = params[:limit] || 20
    
    if defined?(Kaminari)
      @notifications = @notifications.page(page).per(per_page)
      pagination = {
        current_page: @notifications.current_page,
        total_pages: @notifications.total_pages,
        total_count: @notifications.total_count,
        per_page: @notifications.limit_value
      }
    else
      @notifications = @notifications.limit(per_page).offset((page.to_i - 1) * per_page.to_i)
      pagination = { page: page, per_page: per_page }
    end

    render json: {
      notifications: @notifications.map { |n| notification_json(n) },
      pagination: pagination,
      unread_count: current_user.notifications.unread.count,
      status: 'success'
    }
  end

  # GET /notifications/:id
  def show
    render json: {
      notification: notification_json(@notification),
      status: 'success'
    }
  end

  # GET /notifications/unread
  def unread
    @notifications = current_user.notifications
                                 .unread
                                 .active
                                 .includes(:project, :tender, :task, :sender)
                                 .order(created_at: :desc)
                                 .limit(params[:limit] || 20)

    render json: {
      notifications: @notifications.map { |n| notification_json(n) },
      unread_count: current_user.notifications.unread.count,
      status: 'success'
    }
  end

  # GET /notifications/unread_count
  def unread_count
    render json: {
      unread_count: current_user.notifications.unread.count,
      urgent_count: current_user.notifications.unread.where(notification_type: 'urgent').count,
      action_required_count: current_user.notifications.action_required.count,
      status: 'success'
    }
  end

  # GET /notifications/stats
  def stats
    base = current_user.notifications

    render json: {
      stats: {
        total: base.count,
        unread: base.unread.count,
        read: base.read.count,
        urgent: base.unread.where(notification_type: 'urgent').count,
        warnings: base.unread.where(notification_type: 'warning').count,
        action_required: base.action_required.count,
        archived: base.archived.count,
        today: base.where('created_at >= ?', Date.current.beginning_of_day).count,
        this_week: base.where('created_at >= ?', 1.week.ago).count,
        by_category: base.group(:category).count,
        by_type: base.group(:notification_type).count,
        by_priority: base.group(:priority).count
      },
      status: 'success'
    }
  end

  # POST/PATCH /notifications/:id/mark_read
  def mark_read
    @notification.mark_as_read!
    
    render json: {
      message: 'Notification marked as read',
      notification: notification_json(@notification),
      unread_count: current_user.notifications.unread.count,
      status: 'success'
    }
  end

  # POST/PATCH /notifications/:id/mark_unread
  def mark_unread
    @notification.mark_as_unread!
    
    render json: {
      message: 'Notification marked as unread',
      notification: notification_json(@notification),
      unread_count: current_user.notifications.unread.count,
      status: 'success'
    }
  end

  # POST/PATCH /notifications/mark_all_read
  def mark_all_read
    scope = current_user.notifications.unread
    
    # Filter by category if provided
    scope = scope.where(category: params[:category]) if params[:category].present?
    
    count = scope.update_all(is_read: true, read_at: Time.current)

    render json: {
      message: 'All notifications marked as read',
      updated_count: count,
      unread_count: current_user.notifications.unread.count,
      status: 'success'
    }
  end

  # POST /notifications/bulk_mark_read
  def bulk_mark_read
    notification_ids = params[:notification_ids] || []
    
    notifications = current_user.notifications.where(id: notification_ids)
    count = notifications.update_all(is_read: true, read_at: Time.current)

    render json: {
      message: "#{count} notifications marked as read",
      updated_count: count,
      unread_count: current_user.notifications.unread.count,
      status: 'success'
    }
  end

  # POST /notifications/bulk_delete
  def bulk_delete
    notification_ids = params[:notification_ids] || []
    
    notifications = current_user.notifications.where(id: notification_ids)
    count = notifications.destroy_all.count

    render json: {
      message: "#{count} notifications deleted",
      deleted_count: count,
      status: 'success'
    }
  end

  # PATCH /notifications/:id/archive
  def archive
    @notification.archive!
    
    render json: {
      message: 'Notification archived',
      notification: notification_json(@notification),
      status: 'success'
    }
  end

  # DELETE /notifications/:id
  def destroy
    @notification.destroy!
    
    render json: {
      message: 'Notification deleted',
      status: 'success'
    }
  end

  # DELETE /notifications/clear_all
  def clear_all
    # Only delete read notifications by default
    scope = params[:include_unread] ? current_user.notifications : current_user.notifications.read
    count = scope.destroy_all.count

    render json: {
      message: "#{count} notifications cleared",
      deleted_count: count,
      status: 'success'
    }
  end

  # GET /notifications/settings
  def settings
    render json: {
      settings: current_user.notification_settings || default_settings,
      status: 'success'
    }
  end

  # PATCH /notifications/update_settings
  def update_settings
    settings = params[:settings]&.to_unsafe_h || {}
    
    current_user.update!(notification_settings: settings)
    
    render json: {
      message: 'Notification settings updated',
      settings: current_user.notification_settings,
      status: 'success'
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: e.message,
      status: 'error'
    }, status: :unprocessable_entity
  end

  # ============================================================================
  # NOTIFICATION CREATION ENDPOINTS
  # ============================================================================

  # POST /notifications/create_project_notification
  def create_project_notification
    project = Project.find(params[:project_id])
    activity = params[:activity]

    case activity
    when 'created'
      NotificationService.project_created(project, current_user)
    when 'updated'
      NotificationService.project_updated(project, current_user, params[:changes] || {})
    when 'status_changed'
      NotificationService.project_status_changed(project, current_user, params[:old_status], params[:new_status])
    when 'progress_updated'
      NotificationService.project_progress_updated(project, current_user, params[:old_progress].to_f, params[:new_progress].to_f, params[:notes])
    when 'completed'
      NotificationService.project_completed(project, current_user)
    when 'deadline_approaching'
      days_left = (project.finishing_date - Date.current).to_i
      NotificationService.project_deadline_approaching(project, days_left)
    when 'behind_schedule'
      NotificationService.project_behind_schedule(project, params[:variance].to_f)
    else
      return render json: { error: 'Unknown activity type', status: 'error' }, status: :bad_request
    end

    render json: { message: 'Project notification created successfully', status: 'success' }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found', status: 'error' }, status: :not_found
  end

  # POST /notifications/create_tender_notification
  def create_tender_notification
    tender = Tender.find(params[:tender_id])
    activity = params[:activity]

    case activity
    when 'created'
      NotificationService.tender_created(tender, current_user)
    when 'updated'
      NotificationService.tender_updated(tender, current_user, params[:changes] || {})
    when 'status_changed'
      NotificationService.tender_status_changed(tender, current_user, params[:old_status], params[:new_status])
    when 'converted'
      project = Project.find(params[:project_id])
      NotificationService.tender_converted_to_project(tender, project, current_user)
    when 'deadline_approaching'
      days_left = (tender.deadline - Date.current).to_i
      NotificationService.tender_deadline_approaching(tender, days_left)
    when 'expired'
      NotificationService.tender_expired(tender)
    else
      return render json: { error: 'Unknown activity type', status: 'error' }, status: :bad_request
    end

    render json: { message: 'Tender notification created successfully', status: 'success' }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tender not found', status: 'error' }, status: :not_found
  end

  # POST /notifications/create_task_notification
  def create_task_notification
    task = Task.find(params[:task_id])
    activity = params[:activity]

    case activity
    when 'created'
      NotificationService.task_created(task, current_user)
    when 'assigned'
      assignee = User.find(params[:assignee_id])
      NotificationService.task_assigned(task, assignee, current_user)
    when 'status_changed'
      NotificationService.task_status_changed(task, current_user, params[:old_status], params[:new_status])
    when 'completed'
      NotificationService.task_completed(task, current_user)
    when 'due_soon'
      days_left = (task.due_date - Date.current).to_i
      NotificationService.task_due_soon(task, days_left)
    when 'overdue'
      NotificationService.task_overdue(task)
    else
      return render json: { error: 'Unknown activity type', status: 'error' }, status: :bad_request
    end

    render json: { message: 'Task notification created successfully', status: 'success' }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Task or User not found', status: 'error' }, status: :not_found
  end

  # POST /notifications/create_system_notification
  def create_system_notification
    unless current_user.admin?
      return render json: { error: 'Only admins can send system notifications', status: 'error' }, status: :forbidden
    end

    NotificationService.system_announcement(
      title: params[:title],
      message: params[:message],
      user_ids: params[:user_ids],
      priority: params[:priority] || 'medium'
    )

    render json: { message: 'System notification sent successfully', status: 'success' }, status: :created
  end

  # ============================================================================
  # PRIVATE METHODS
  # ============================================================================

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Notification not found', status: 'error' }, status: :not_found
  end

  def filter_params
    {
      search: params[:search],
      notification_type: params[:type] || params[:notification_type],
      category: params[:category],
      priority: params[:priority],
      status: params[:status],
      sort_by: params[:sort_by] || 'created_at',
      sort_direction: params[:sort_direction] || 'desc'
    }
  end

  def notification_json(notification)
    {
      id: notification.id,
      type: notification.notification_type,
      category: notification.category,
      title: notification.title,
      message: notification.message,
      priority: notification.priority,
      isRead: notification.is_read,
      readAt: notification.read_at&.iso8601,
      actionRequired: notification.action_required,
      actionUrl: notification.action_url,
      
      # Timestamps
      timestamp: notification.created_at.iso8601,
      createdAt: notification.created_at.iso8601,
      timeAgo: time_ago_in_words(notification.created_at),
      
      # Related entities
      project: notification.project ? {
        id: notification.project.id,
        title: notification.project.title
      } : nil,
      projectId: notification.project_id,
      
      tender: notification.tender ? {
        id: notification.tender.id,
        title: notification.tender.title
      } : nil,
      tenderId: notification.tender_id,
      
      task: notification.task ? {
        id: notification.task.id,
        title: notification.task.title
      } : nil,
      taskId: notification.task_id,
      
      # Sender info
      sender: notification.sender&.name || notification.sender_name || 'System',
      senderId: notification.sender_id,
      
      # UI helpers
      icon: get_notification_icon(notification),
      color: get_notification_color(notification),
      
      # Extra data
      metadata: notification.metadata || {},
      tags: notification.tags || []
    }
  end

  def time_ago_in_words(time)
    return 'just now' if time > 1.minute.ago
    
    seconds = (Time.current - time).to_i
    
    case seconds
    when 0..59
      'just now'
    when 60..3599
      "#{seconds / 60} minute#{'s' if seconds / 60 > 1} ago"
    when 3600..86399
      "#{seconds / 3600} hour#{'s' if seconds / 3600 > 1} ago"
    when 86400..172799
      'yesterday'
    when 172800..604799
      "#{seconds / 86400} days ago"
    when 604800..2419199
      "#{seconds / 604800} week#{'s' if seconds / 604800 > 1} ago"
    else
      time.strftime('%B %d, %Y')
    end
  end

  def get_notification_icon(notification)
    case notification.category
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
    when 'system' then 'settings'
    else 'bell'
    end
  end

  def get_notification_color(notification)
    case notification.notification_type
    when 'urgent' then 'red'
    when 'error' then 'red'
    when 'warning' then 'yellow'
    when 'success' then 'green'
    when 'info' then 'blue'
    else 'gray'
    end
  end

  def default_settings
    {
      email_notifications: true,
      push_notifications: true,
      urgent_only: false,
      quiet_hours: {
        enabled: false,
        start: '22:00',
        end: '07:00'
      },
      categories: {
        system: true,
        project: true,
        tender: true,
        task: true,
        deadline: true,
        budget: true,
        safety: true,
        meeting: true
      }
    }
  end
end