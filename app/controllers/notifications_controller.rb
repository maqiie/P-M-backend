# app/controllers/api/v1/notifications_controller.rb
class Api::V1::NotificationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_notification, only: [:show, :mark_read, :mark_unread, :destroy]
  
    def index
      @notifications = current_user.notifications
                                   .includes(:project, :sender, :tender, :task)
                                   .apply_filters(filter_params)
                                   .page(params[:page] || 1)
                                   .per(params[:limit] || 20)
  
      render json: {
        notifications: @notifications.map { |notification| notification_json(notification) },
        pagination: {
          current_page: @notifications.current_page,
          total_pages: @notifications.total_pages,
          total_count: @notifications.total_count,
          per_page: @notifications.limit_value
        }
      }, status: :ok
    end
  
    def show
      render json: { notification: notification_json(@notification) }, status: :ok
    end
  
    def stats
      stats = calculate_notification_stats
      render json: { stats: stats }, status: :ok
    end
  
    def mark_read
      @notification.mark_as_read!
      render json: { 
        message: 'Notification marked as read',
        notification: notification_json(@notification)
      }, status: :ok
    end
  
    def mark_unread
      @notification.mark_as_unread!
      render json: { 
        message: 'Notification marked as unread',
        notification: notification_json(@notification)
      }, status: :ok
    end
  
    def mark_all_read
      current_user.notifications.unread.update_all(
        is_read: true, 
        read_at: Time.current
      )
      
      render json: { 
        message: 'All notifications marked as read',
        updated_count: current_user.notifications.unread.count
      }, status: :ok
    end
  
    def bulk_mark_read
      notification_ids = params[:notification_ids] || []
      
      notifications = current_user.notifications.where(id: notification_ids)
      notifications.update_all(is_read: true, read_at: Time.current)
  
      render json: { 
        message: "#{notifications.count} notifications marked as read",
        updated_count: notifications.count
      }, status: :ok
    end
  
    def bulk_delete
      notification_ids = params[:notification_ids] || []
      
      notifications = current_user.notifications.where(id: notification_ids)
      deleted_count = notifications.count
      notifications.destroy_all
  
      render json: { 
        message: "#{deleted_count} notifications deleted",
        deleted_count: deleted_count
      }, status: :ok
    end
  
    def destroy
      @notification.destroy!
      render json: { message: 'Notification deleted' }, status: :ok
    end
  
    def settings
      settings = current_user.notification_settings || build_default_settings
      render json: { settings: settings }, status: :ok
    end
  
    def update_settings
      settings = params[:settings] || {}
      
      current_user.update!(notification_settings: settings)
      
      render json: { 
        message: 'Notification settings updated',
        settings: current_user.notification_settings
      }, status: :ok
    end
  
    # Create notifications for different activities
    def create_tender_notification
      tender = Tender.find(params[:tender_id])
      activity = params[:activity] # 'created', 'updated', 'status_changed', 'deadline_approaching'
      
      case activity
      when 'created'
        create_tender_created_notification(tender)
      when 'updated'
        create_tender_updated_notification(tender)
      when 'status_changed'
        create_tender_status_changed_notification(tender, params[:old_status], params[:new_status])
      when 'deadline_approaching'
        create_tender_deadline_notification(tender)
      when 'converted'
        create_tender_converted_notification(tender, params[:project_id])
      end
      
      render json: { message: 'Notification created successfully' }, status: :created
    end
  
    def create_project_notification
      project = Project.find(params[:project_id])
      activity = params[:activity] # 'created', 'updated', 'status_changed', 'progress_updated', 'milestone_reached'
      
      case activity
      when 'created'
        create_project_created_notification(project)
      when 'updated'
        create_project_updated_notification(project)
      when 'status_changed'
        create_project_status_changed_notification(project, params[:old_status], params[:new_status])
      when 'progress_updated'
        create_project_progress_notification(project, params[:old_progress], params[:new_progress])
      when 'milestone_reached'
        create_project_milestone_notification(project, params[:milestone_name])
      when 'budget_alert'
        create_project_budget_alert(project, params[:utilization_percentage])
      when 'deadline_approaching'
        create_project_deadline_notification(project)
      end
      
      render json: { message: 'Notification created successfully' }, status: :created
    end
  
    def create_task_notification
      task = Task.find(params[:task_id])
      activity = params[:activity] # 'created', 'assigned', 'status_changed', 'overdue', 'completed'
      
      case activity
      when 'created'
        create_task_created_notification(task)
      when 'assigned'
        create_task_assigned_notification(task, params[:assignee_ids])
      when 'status_changed'
        create_task_status_changed_notification(task, params[:old_status], params[:new_status])
      when 'overdue'
        create_task_overdue_notification(task)
      when 'completed'
        create_task_completed_notification(task)
      when 'due_today'
        create_task_due_today_notification(task)
      end
      
      render json: { message: 'Notification created successfully' }, status: :created
    end
  
    def create_system_notification
      users = params[:user_ids] ? User.where(id: params[:user_ids]) : User.all
      
      users.each do |user|
        Notification.create!(
          user: user,
          title: params[:title],
          message: params[:message],
          notification_type: params[:type] || 'info',
          category: params[:category] || 'system',
          priority: params[:priority] || 'medium',
          action_required: params[:action_required] || false,
          sender_name: 'System Administrator',
          metadata: params[:metadata] || {}
        )
      end
      
      render json: { 
        message: "System notification sent to #{users.count} users" 
      }, status: :created
    end
  
    private
  
    def set_notification
      @notification = current_user.notifications.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Notification not found' }, status: :not_found
    end
  
    def filter_params
      {
        search: params[:search],
        notification_type: params[:type],
        status: params[:status],
        sort_by: params[:sort_by] || 'created_at',
        sort_direction: params[:sort_direction] || 'desc'
      }
    end
  
    def calculate_notification_stats
      base_query = current_user.notifications
      
      {
        total: base_query.count,
        unread: base_query.unread.count,
        urgent: base_query.unread.where(notification_type: 'urgent').count,
        action_required: base_query.unread.where(action_required: true).count,
        by_category: base_query.group(:category).count,
        by_type: base_query.group(:notification_type).count,
        today: base_query.where('created_at >= ?', Date.current.beginning_of_day).count,
        this_week: base_query.where('created_at >= ?', 1.week.ago).count
      }
    end
  
    def notification_json(notification)
      {
        id: notification.id,
        type: notification.notification_type,
        category: notification.category,
        title: notification.title,
        message: notification.message,
        project: notification.project&.title,
        project_id: notification.project_id,
        tender: notification.tender&.title,
        tender_id: notification.tender_id,
        task: notification.task&.title,
        task_id: notification.task_id,
        sender: notification.sender&.name || notification.sender_name,
        timestamp: notification.created_at.iso8601,
        isRead: notification.is_read,
        priority: notification.priority,
        actionRequired: notification.action_required,
        relatedUsers: notification.related_users.pluck(:name),
        tags: notification.tags || [],
        metadata: notification.metadata || {}
      }
    end
  
    def build_default_settings
      {
        email_notifications: true,
        push_notifications: true,
        urgent_only: false,
        categories: {
          safety: true,
          project: true,
          budget: true,
          delivery: true,
          meeting: true,
          deadline: true,
          equipment: true,
          approval: true,
          training: true,
          weather: true,
          tender: true,
          task: true,
          system: true
        }
      }
    end
  
    # Tender notification methods
    def create_tender_created_notification(tender)
      # Notify all relevant users about new tender
      relevant_users = get_tender_stakeholders(tender)
      
      relevant_users.each do |user|
        next if user == current_user # Don't notify the creator
        
        Notification.create!(
          user: user,
          tender: tender,
          project: tender.project,
          title: "New Tender Created",
          message: "#{tender.title} has been created by #{current_user.name}. Deadline: #{tender.deadline&.strftime('%B %d, %Y')}",
          notification_type: 'info',
          category: 'tender',
          priority: get_tender_priority(tender),
          action_required: user.role == 'admin' || user.role == 'project_manager',
          sender: current_user,
          metadata: {
            tender_id: tender.id,
            deadline: tender.deadline,
            budget_estimate: tender.budget_estimate,
            category: tender.category
          }
        )
      end
    end
  
    def create_tender_updated_notification(tender)
      relevant_users = get_tender_stakeholders(tender)
      
      relevant_users.each do |user|
        next if user == current_user
        
        Notification.create!(
          user: user,
          tender: tender,
          project: tender.project,
          title: "Tender Updated",
          message: "#{tender.title} has been updated by #{current_user.name}",
          notification_type: 'info',
          category: 'tender',
          priority: 'medium',
          action_required: false,
          sender: current_user,
          metadata: { tender_id: tender.id, updated_at: Time.current }
        )
      end
    end
  
    def create_tender_status_changed_notification(tender, old_status, new_status)
      relevant_users = get_tender_stakeholders(tender)
      
      notification_type = case new_status
                         when 'approved', 'won' then 'success'
                         when 'rejected', 'lost' then 'warning'
                         when 'urgent' then 'urgent'
                         else 'info'
                         end
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          tender: tender,
          project: tender.project,
          title: "Tender Status Changed",
          message: "#{tender.title} status changed from #{old_status.humanize} to #{new_status.humanize}",
          notification_type: notification_type,
          category: 'tender',
          priority: notification_type == 'urgent' ? 'high' : 'medium',
          action_required: ['pending_review', 'requires_action'].include?(new_status),
          sender: current_user,
          metadata: {
            tender_id: tender.id,
            old_status: old_status,
            new_status: new_status,
            changed_by: current_user.name
          }
        )
      end
    end
  
    def create_tender_deadline_notification(tender)
      relevant_users = get_tender_stakeholders(tender)
      days_left = (tender.deadline - Date.current).to_i
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          tender: tender,
          project: tender.project,
          title: "Tender Deadline Approaching",
          message: "#{tender.title} deadline is in #{days_left} day#{'s' if days_left != 1} (#{tender.deadline.strftime('%B %d, %Y')})",
          notification_type: days_left <= 1 ? 'urgent' : 'warning',
          category: 'deadline',
          priority: 'high',
          action_required: true,
          sender_name: 'System',
          metadata: {
            tender_id: tender.id,
            deadline: tender.deadline,
            days_left: days_left
          }
        )
      end
    end
  
    def create_tender_converted_notification(tender, project_id)
      project = Project.find(project_id)
      relevant_users = get_tender_stakeholders(tender) + get_project_stakeholders(project)
      
      relevant_users.uniq.each do |user|
        Notification.create!(
          user: user,
          tender: tender,
          project: project,
          title: "Tender Converted to Project",
          message: "#{tender.title} has been successfully converted to project: #{project.title}",
          notification_type: 'success',
          category: 'project',
          priority: 'medium',
          action_required: false,
          sender: current_user,
          metadata: {
            tender_id: tender.id,
            project_id: project.id,
            converted_by: current_user.name
          }
        )
      end
    end
  
    # Project notification methods
    def create_project_created_notification(project)
      relevant_users = get_project_stakeholders(project)
      
      relevant_users.each do |user|
        next if user == current_user
        
        Notification.create!(
          user: user,
          project: project,
          title: "New Project Created",
          message: "#{project.title} has been created. Start date: #{project.start_date&.strftime('%B %d, %Y')}",
          notification_type: 'info',
          category: 'project',
          priority: project.priority == 'high' ? 'high' : 'medium',
          action_required: user.id == project.project_manager_id || user.id == project.supervisor_id,
          sender: current_user,
          metadata: {
            project_id: project.id,
            start_date: project.start_date,
            budget: project.budget,
            priority: project.priority
          }
        )
      end
    end
  
    def create_project_status_changed_notification(project, old_status, new_status)
      relevant_users = get_project_stakeholders(project)
      
      notification_type = case new_status
                         when 'completed' then 'success'
                         when 'on_hold', 'cancelled' then 'warning'
                         when 'delayed' then 'urgent'
                         else 'info'
                         end
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          project: project,
          title: "Project Status Changed",
          message: "#{project.title} status changed from #{old_status.humanize} to #{new_status.humanize}",
          notification_type: notification_type,
          category: 'project',
          priority: notification_type == 'urgent' ? 'high' : 'medium',
          action_required: ['on_hold', 'delayed'].include?(new_status),
          sender: current_user,
          metadata: {
            project_id: project.id,
            old_status: old_status,
            new_status: new_status
          }
        )
      end
    end
  
    def create_project_progress_notification(project, old_progress, new_progress)
      relevant_users = get_project_stakeholders(project)
      progress_diff = new_progress - old_progress
      
      # Only notify for significant progress changes (>= 5%)
      return if progress_diff.abs < 5
      
      relevant_users.each do |user|
        next if user == current_user
        
        Notification.create!(
          user: user,
          project: project,
          title: "Project Progress Updated",
          message: "#{project.title} progress updated from #{old_progress}% to #{new_progress}% (#{progress_diff > 0 ? '+' : ''}#{progress_diff.round(1)}%)",
          notification_type: progress_diff > 0 ? 'success' : 'warning',
          category: 'project',
          priority: 'medium',
          action_required: false,
          sender: current_user,
          metadata: {
            project_id: project.id,
            old_progress: old_progress,
            new_progress: new_progress,
            progress_diff: progress_diff
          }
        )
      end
    end
  
    def create_project_milestone_notification(project, milestone_name)
      relevant_users = get_project_stakeholders(project)
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          project: project,
          title: "Project Milestone Reached",
          message: "#{project.title} has reached milestone: #{milestone_name}",
          notification_type: 'success',
          category: 'project',
          priority: 'medium',
          action_required: false,
          sender: current_user,
          metadata: {
            project_id: project.id,
            milestone_name: milestone_name,
            achieved_by: current_user.name
          }
        )
      end
    end
  
    def create_project_budget_alert(project, utilization_percentage)
      relevant_users = get_project_stakeholders(project)
      
      notification_type = utilization_percentage >= 90 ? 'urgent' : 'warning'
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          project: project,
          title: "Project Budget Alert",
          message: "#{project.title} is at #{utilization_percentage}% budget utilization. Review recommended.",
          notification_type: notification_type,
          category: 'budget',
          priority: 'high',
          action_required: true,
          sender_name: 'Finance System',
          metadata: {
            project_id: project.id,
            utilization_percentage: utilization_percentage,
            budget: project.budget
          }
        )
      end
    end
  
    def create_project_deadline_notification(project)
      relevant_users = get_project_stakeholders(project)
      days_left = (project.finishing_date - Date.current).to_i
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          project: project,
          title: "Project Deadline Approaching",
          message: "#{project.title} deadline is in #{days_left} day#{'s' if days_left != 1} (#{project.finishing_date.strftime('%B %d, %Y')})",
          notification_type: days_left <= 1 ? 'urgent' : 'warning',
          category: 'deadline',
          priority: 'high',
          action_required: true,
          sender_name: 'System',
          metadata: {
            project_id: project.id,
            deadline: project.finishing_date,
            days_left: days_left
          }
        )
      end
    end
  
    # Task notification methods
    def create_task_created_notification(task)
      relevant_users = get_task_stakeholders(task)
      
      relevant_users.each do |user|
        next if user == current_user
        
        Notification.create!(
          user: user,
          task: task,
          project: task.project,
          title: "New Task Created",
          message: "#{task.title} has been created. Due: #{task.due_date&.strftime('%B %d, %Y')}",
          notification_type: 'info',
          category: 'task',
          priority: map_task_priority(task.priority),
          action_required: task.assignees.include?(user),
          sender: current_user,
          metadata: {
            task_id: task.id,
            due_date: task.due_date,
            priority: task.priority,
            estimated_hours: task.estimated_hours
          }
        )
      end
    end
  
    def create_task_assigned_notification(task, assignee_ids)
      assignees = User.where(id: assignee_ids)
      
      assignees.each do |assignee|
        next if assignee == current_user
        
        Notification.create!(
          user: assignee,
          task: task,
          project: task.project,
          title: "Task Assigned to You",
          message: "You have been assigned to task: #{task.title}. Due: #{task.due_date&.strftime('%B %d, %Y')}",
          notification_type: task.priority == 'urgent' ? 'urgent' : 'info',
          category: 'task',
          priority: map_task_priority(task.priority),
          action_required: true,
          sender: current_user,
          metadata: {
            task_id: task.id,
            assigned_by: current_user.name,
            due_date: task.due_date
          }
        )
      end
    end
  
    def create_task_status_changed_notification(task, old_status, new_status)
      relevant_users = get_task_stakeholders(task)
      
      notification_type = case new_status
                         when 'completed' then 'success'
                         when 'cancelled', 'on_hold' then 'warning'
                         when 'urgent' then 'urgent'
                         else 'info'
                         end
      
      relevant_users.each do |user|
        next if user == current_user
        
        Notification.create!(
          user: user,
          task: task,
          project: task.project,
          title: "Task Status Changed",
          message: "#{task.title} status changed from #{old_status.humanize} to #{new_status.humanize}",
          notification_type: notification_type,
          category: 'task',
          priority: notification_type == 'urgent' ? 'high' : 'medium',
          action_required: false,
          sender: current_user,
          metadata: {
            task_id: task.id,
            old_status: old_status,
            new_status: new_status
          }
        )
      end
    end
  
    def create_task_overdue_notification(task)
      relevant_users = get_task_stakeholders(task)
      days_overdue = (Date.current - task.due_date).to_i
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          task: task,
          project: task.project,
          title: "Task Overdue",
          message: "#{task.title} is #{days_overdue} day#{'s' if days_overdue != 1} overdue. Immediate attention required.",
          notification_type: 'urgent',
          category: 'deadline',
          priority: 'high',
          action_required: true,
          sender_name: 'System',
          metadata: {
            task_id: task.id,
            due_date: task.due_date,
            days_overdue: days_overdue
          }
        )
      end
    end
  
    def create_task_completed_notification(task)
      relevant_users = get_task_stakeholders(task)
      
      relevant_users.each do |user|
        next if user == current_user
        
        Notification.create!(
          user: user,
          task: task,
          project: task.project,
          title: "Task Completed",
          message: "#{task.title} has been marked as completed by #{current_user.name}",
          notification_type: 'success',
          category: 'task',
          priority: 'low',
          action_required: false,
          sender: current_user,
          metadata: {
            task_id: task.id,
            completed_by: current_user.name,
            completed_at: Time.current
          }
        )
      end
    end
  
    def create_task_due_today_notification(task)
      relevant_users = get_task_stakeholders(task)
      
      relevant_users.each do |user|
        Notification.create!(
          user: user,
          task: task,
          project: task.project,
          title: "Task Due Today",
          message: "#{task.title} is due today. Please ensure completion.",
          notification_type: 'warning',
          category: 'deadline',
          priority: 'high',
          action_required: task.assignees.include?(user),
          sender_name: 'System',
          metadata: {
            task_id: task.id,
            due_date: task.due_date
          }
        )
      end
    end
  
    # Helper methods for getting stakeholders
    def get_tender_stakeholders(tender)
      users = []
      users << tender.user if tender.user
      users << tender.project_manager if tender.project_manager
      users += User.where(admin: true) # Notify admins
      users.compact.uniq
    end
  
    def get_project_stakeholders(project)
      users = []
      users << project.project_manager if project.project_manager
      users << project.supervisor if project.supervisor
      users << project.site_manager if project.site_manager
      users += User.where(admin: true) # Notify admins
      users.compact.uniq
    end
  
    def get_task_stakeholders(task)
      users = []
      users += task.assignees if task.assignees.any?
      users += task.watchers if task.watchers.any?
      users << task.project_manager if task.project_manager
      users << task.project&.project_manager if task.project&.project_manager
      users << task.project&.supervisor if task.project&.supervisor
      users.compact.uniq
    end
  
    def get_tender_priority(tender)
      return 'high' if tender.deadline && tender.deadline <= 3.days.from_now
      return 'high' if tender.priority == 'high'
      'medium'
    end
  
    def map_task_priority(task_priority)
      case task_priority
      when 'urgent', 'high' then 'high'
      when 'low' then 'low'
      else 'medium'
      end
    end
  end