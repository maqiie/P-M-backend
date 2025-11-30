# app/jobs/notification_job.rb
#
# Processes notifications - works with or without Redis/Sidekiq

class NotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(notification_type, payload)
    # Ensure notification_type is a string
    type = notification_type.to_s
    
    # Ensure payload keys are accessible as both strings and symbols
    data = payload.is_a?(Hash) ? payload.with_indifferent_access : {}
    
    Rails.logger.info "NotificationJob processing: #{type}"

    case type
    # Project notifications
    when 'project_created'
      process_project_created(data)
    when 'project_updated'
      process_project_updated(data)
    when 'project_status_changed'
      process_project_status_changed(data)
    when 'project_progress_updated'
      process_project_progress_updated(data)
    when 'project_completed'
      process_project_completed(data)
    when 'project_deadline_approaching'
      process_project_deadline_approaching(data)
    when 'project_overdue'
      process_project_overdue(data)

    # Tender notifications
    when 'tender_created'
      process_tender_created(data)
    when 'tender_updated'
      process_tender_updated(data)
    when 'tender_status_changed'
      process_tender_status_changed(data)
    when 'tender_converted'
      process_tender_converted(data)
    when 'tender_deadline_approaching'
      process_tender_deadline_approaching(data)

    # Task notifications
    when 'task_created'
      process_task_created(data)
    when 'task_assigned'
      process_task_assigned(data)
    when 'task_status_changed'
      process_task_status_changed(data)
    when 'task_completed'
      process_task_completed(data)
    when 'task_overdue'
      process_task_overdue(data)

    # System notifications
    when 'system_announcement'
      process_system_announcement(data)
    when 'welcome'
      process_welcome(data)

    else
      Rails.logger.warn "NotificationJob: Unknown type '#{type}' (original: #{notification_type.inspect})"
    end
  rescue => e
    Rails.logger.error "NotificationJob error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  private

  # ============================================================================
  # PROJECT PROCESSORS
  # ============================================================================

  def process_project_created(data)
    project = Project.find(data[:project_id])
    created_by = User.find(data[:created_by_id])

    get_project_stakeholders(project).each do |user|
      next if user.id == created_by.id

      create_notification(
        user: user,
        project: project,
        sender: created_by,
        title: "New Project Created",
        message: "#{project.title} has been created by #{created_by.name}",
        notification_type: 'info',
        category: 'project',
        priority: map_priority(project.priority),
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: project_created processed"
  end

  def process_project_updated(data)
    project = Project.find(data[:project_id])
    updated_by = User.find(data[:updated_by_id])

    get_project_stakeholders(project).each do |user|
      next if user.id == updated_by.id

      create_notification(
        user: user,
        project: project,
        sender: updated_by,
        title: "Project Updated",
        message: "#{project.title} has been updated",
        notification_type: 'info',
        category: 'project',
        priority: 'medium',
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: project_updated processed"
  end

  def process_project_status_changed(data)
    project = Project.find(data[:project_id])
    changed_by = User.find(data[:changed_by_id])
    old_status = data[:old_status].to_s
    new_status = data[:new_status].to_s

    notif_type = case new_status
                 when 'completed' then 'success'
                 when 'on_hold', 'cancelled' then 'warning'
                 when 'at_risk' then 'urgent'
                 else 'info'
                 end

    get_project_stakeholders(project).each do |user|
      create_notification(
        user: user,
        project: project,
        sender: changed_by,
        title: "Project Status Changed",
        message: "#{project.title}: #{old_status.humanize} → #{new_status.humanize}",
        notification_type: notif_type,
        category: 'project',
        priority: notif_type == 'urgent' ? 'high' : 'medium',
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: project_status_changed processed"
  end

  def process_project_progress_updated(data)
    project = Project.find(data[:project_id])
    updated_by = User.find(data[:updated_by_id])
    old_progress = data[:old_progress].to_f
    new_progress = data[:new_progress].to_f
    progress_diff = new_progress - old_progress

    get_project_stakeholders(project).each do |user|
      next if user.id == updated_by.id

      create_notification(
        user: user,
        project: project,
        sender: updated_by,
        title: "Project Progress Updated",
        message: "#{project.title}: #{old_progress.round(1)}% → #{new_progress.round(1)}%",
        notification_type: progress_diff > 0 ? 'success' : 'warning',
        category: 'project',
        priority: 'medium',
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: project_progress_updated processed"
  end

  def process_project_completed(data)
    project = Project.find(data[:project_id])
    completed_by = User.find(data[:completed_by_id])

    get_project_stakeholders(project).each do |user|
      create_notification(
        user: user,
        project: project,
        sender: completed_by,
        title: "🎉 Project Completed!",
        message: "#{project.title} has been marked as completed",
        notification_type: 'success',
        category: 'project',
        priority: 'medium',
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: project_completed processed for #{get_project_stakeholders(project).count} users"
  end

  def process_project_deadline_approaching(data)
    project = Project.find(data[:project_id])
    days_left = data[:days_left].to_i

    get_project_stakeholders(project).each do |user|
      create_notification(
        user: user,
        project: project,
        sender_name: 'System',
        title: "Project Deadline Approaching",
        message: "#{project.title} is due in #{days_left} day#{'s' if days_left != 1}",
        notification_type: days_left <= 1 ? 'urgent' : 'warning',
        category: 'deadline',
        priority: 'high',
        action_required: true,
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: project_deadline_approaching processed"
  end

  def process_project_overdue(data)
    project = Project.find(data[:project_id])
    days_overdue = project.finishing_date ? (Date.current - project.finishing_date).to_i : 0

    get_project_stakeholders(project).each do |user|
      create_notification(
        user: user,
        project: project,
        sender_name: 'System',
        title: "⚠️ Project Overdue",
        message: "#{project.title} is #{days_overdue} day#{'s' if days_overdue != 1} overdue!",
        notification_type: 'urgent',
        category: 'deadline',
        priority: 'high',
        action_required: true,
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: project_overdue processed"
  end

  # ============================================================================
  # TENDER PROCESSORS
  # ============================================================================

  def process_tender_created(data)
    tender = Tender.find(data[:tender_id])
    created_by = User.find(data[:created_by_id])

    get_tender_stakeholders(tender).each do |user|
      next if user.id == created_by.id

      create_notification(
        user: user,
        tender: tender,
        project: tender.project,
        sender: created_by,
        title: "New Tender Created",
        message: "#{tender.title} - Deadline: #{tender.deadline&.strftime('%B %d, %Y') || 'Not set'}",
        notification_type: 'info',
        category: 'tender',
        priority: tender.deadline && tender.deadline <= 3.days.from_now ? 'high' : 'medium',
        action_url: "/tenders/#{tender.id}"
      )
    end
    Rails.logger.info "NotificationJob: tender_created processed"
  end

  def process_tender_updated(data)
    tender = Tender.find(data[:tender_id])
    updated_by = User.find(data[:updated_by_id])

    get_tender_stakeholders(tender).each do |user|
      next if user.id == updated_by.id

      create_notification(
        user: user,
        tender: tender,
        project: tender.project,
        sender: updated_by,
        title: "Tender Updated",
        message: "#{tender.title} has been updated",
        notification_type: 'info',
        category: 'tender',
        priority: 'medium',
        action_url: "/tenders/#{tender.id}"
      )
    end
    Rails.logger.info "NotificationJob: tender_updated processed"
  end

  def process_tender_status_changed(data)
    tender = Tender.find(data[:tender_id])
    changed_by = User.find(data[:changed_by_id])
    old_status = data[:old_status].to_s
    new_status = data[:new_status].to_s

    notif_type = case new_status
                 when 'active', 'approved' then 'success'
                 when 'rejected', 'cancelled' then 'warning'
                 when 'converted' then 'success'
                 else 'info'
                 end

    get_tender_stakeholders(tender).each do |user|
      create_notification(
        user: user,
        tender: tender,
        project: tender.project,
        sender: changed_by,
        title: "Tender Status Changed",
        message: "#{tender.title}: #{old_status.humanize} → #{new_status.humanize}",
        notification_type: notif_type,
        category: 'tender',
        priority: 'medium',
        action_url: "/tenders/#{tender.id}"
      )
    end
    Rails.logger.info "NotificationJob: tender_status_changed processed"
  end

  def process_tender_converted(data)
    tender = Tender.find(data[:tender_id])
    project = Project.find(data[:project_id])
    converted_by = User.find(data[:converted_by_id])

    stakeholders = (get_tender_stakeholders(tender) + get_project_stakeholders(project)).uniq

    stakeholders.each do |user|
      create_notification(
        user: user,
        tender: tender,
        project: project,
        sender: converted_by,
        title: "🎉 Tender Converted to Project",
        message: "#{tender.title} → #{project.title}",
        notification_type: 'success',
        category: 'project',
        priority: 'medium',
        action_url: "/projects/#{project.id}"
      )
    end
    Rails.logger.info "NotificationJob: tender_converted processed"
  end

  def process_tender_deadline_approaching(data)
    tender = Tender.find(data[:tender_id])
    days_left = data[:days_left].to_i

    get_tender_stakeholders(tender).each do |user|
      create_notification(
        user: user,
        tender: tender,
        project: tender.project,
        sender_name: 'System',
        title: "Tender Deadline Approaching",
        message: "#{tender.title} deadline in #{days_left} day#{'s' if days_left != 1}",
        notification_type: days_left <= 1 ? 'urgent' : 'warning',
        category: 'deadline',
        priority: 'high',
        action_required: true,
        action_url: "/tenders/#{tender.id}"
      )
    end
    Rails.logger.info "NotificationJob: tender_deadline_approaching processed"
  end

  # ============================================================================
  # TASK PROCESSORS
  # ============================================================================

  def process_task_created(data)
    task = Task.find(data[:task_id])
    created_by = User.find(data[:created_by_id])

    get_task_stakeholders(task).each do |user|
      next if user.id == created_by.id

      create_notification(
        user: user,
        task: task,
        project: task.project,
        sender: created_by,
        title: "New Task Created",
        message: "#{task.title} - Due: #{task.due_date&.strftime('%B %d, %Y') || 'Not set'}",
        notification_type: 'info',
        category: 'task',
        priority: map_task_priority(task.priority),
        action_url: "/tasks/#{task.id}"
      )
    end
    Rails.logger.info "NotificationJob: task_created processed"
  end

  def process_task_assigned(data)
    task = Task.find(data[:task_id])
    assignee = User.find(data[:assignee_id])
    assigned_by = User.find(data[:assigned_by_id])

    return if assignee.id == assigned_by.id

    create_notification(
      user: assignee,
      task: task,
      project: task.project,
      sender: assigned_by,
      title: "Task Assigned to You",
      message: "#{task.title} - Due: #{task.due_date&.strftime('%B %d, %Y') || 'Not set'}",
      notification_type: task.priority == 'high' ? 'urgent' : 'info',
      category: 'task',
      priority: map_task_priority(task.priority),
      action_required: true,
      action_url: "/tasks/#{task.id}"
    )
    Rails.logger.info "NotificationJob: task_assigned processed"
  end

  def process_task_status_changed(data)
    task = Task.find(data[:task_id])
    changed_by = User.find(data[:changed_by_id])
    old_status = data[:old_status].to_s
    new_status = data[:new_status].to_s

    notif_type = case new_status
                 when 'completed' then 'success'
                 when 'cancelled', 'blocked' then 'warning'
                 else 'info'
                 end

    get_task_stakeholders(task).each do |user|
      next if user.id == changed_by.id

      create_notification(
        user: user,
        task: task,
        project: task.project,
        sender: changed_by,
        title: "Task Status Changed",
        message: "#{task.title}: #{old_status.humanize} → #{new_status.humanize}",
        notification_type: notif_type,
        category: 'task',
        priority: 'medium',
        action_url: "/tasks/#{task.id}"
      )
    end
    Rails.logger.info "NotificationJob: task_status_changed processed"
  end

  def process_task_completed(data)
    task = Task.find(data[:task_id])
    completed_by = User.find(data[:completed_by_id])

    get_task_stakeholders(task).each do |user|
      next if user.id == completed_by.id

      create_notification(
        user: user,
        task: task,
        project: task.project,
        sender: completed_by,
        title: "✅ Task Completed",
        message: "#{task.title} completed by #{completed_by.name}",
        notification_type: 'success',
        category: 'task',
        priority: 'low',
        action_url: "/tasks/#{task.id}"
      )
    end
    Rails.logger.info "NotificationJob: task_completed processed"
  end

  def process_task_overdue(data)
    task = Task.find(data[:task_id])
    days_overdue = task.due_date ? (Date.current - task.due_date).to_i : 0

    get_task_stakeholders(task).each do |user|
      create_notification(
        user: user,
        task: task,
        project: task.project,
        sender_name: 'System',
        title: "⚠️ Task Overdue",
        message: "#{task.title} is #{days_overdue} day#{'s' if days_overdue != 1} overdue",
        notification_type: 'urgent',
        category: 'deadline',
        priority: 'high',
        action_required: true,
        action_url: "/tasks/#{task.id}"
      )
    end
    Rails.logger.info "NotificationJob: task_overdue processed"
  end

  # ============================================================================
  # SYSTEM PROCESSORS
  # ============================================================================

  def process_system_announcement(data)
    users = data[:user_ids] ? User.where(id: data[:user_ids]) : User.all

    users.find_each do |user|
      create_notification(
        user: user,
        title: data[:title],
        message: data[:message],
        notification_type: 'info',
        category: 'system',
        priority: data[:priority] || 'medium',
        sender_name: 'System Administrator'
      )
    end
    Rails.logger.info "NotificationJob: system_announcement processed"
  end

  def process_welcome(data)
    user = User.find(data[:user_id])

    create_notification(
      user: user,
      title: "Welcome! 🎉",
      message: "Your account has been created.",
      notification_type: 'success',
      category: 'system',
      priority: 'medium',
      sender_name: 'System',
      action_url: '/dashboard'
    )
    Rails.logger.info "NotificationJob: welcome processed"
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  def create_notification(attrs)
    Notification.create!(attrs)
    Rails.logger.debug "Notification created: #{attrs[:title]}"
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create notification: #{e.message}"
  rescue => e
    Rails.logger.error "Notification error: #{e.message}"
  end

  def get_project_stakeholders(project)
    users = []
    users << project.project_manager if project.respond_to?(:project_manager) && project.project_manager
    users << project.supervisor if project.respond_to?(:supervisor) && project.supervisor
    users << project.site_manager if project.respond_to?(:site_manager) && project.site_manager.is_a?(User)
    users << User.find_by(id: project.user_id) if project.user_id
    users += User.where(admin: true) if User.column_names.include?('admin')
    users.compact.uniq
  end

  def get_tender_stakeholders(tender)
    users = []
    users << tender.user if tender.respond_to?(:user) && tender.user
    users << tender.project_manager if tender.respond_to?(:project_manager) && tender.project_manager
    users += User.where(admin: true) if User.column_names.include?('admin')
    users.compact.uniq
  end

  def get_task_stakeholders(task)
    users = []
    users += task.assignees.to_a if task.respond_to?(:assignees) && task.assignees.any?
    users << task.project&.project_manager if task.project&.project_manager
    users << task.project&.supervisor if task.project&.supervisor
    users.compact.uniq
  end

  def map_priority(priority)
    case priority.to_s
    when '2', 'high', 'critical' then 'high'
    when '0', 'low' then 'low'
    else 'medium'
    end
  end

  def map_task_priority(priority)
    case priority.to_s
    when 'high', 'urgent' then 'high'
    when 'low' then 'low'
    else 'medium'
    end
  end
end