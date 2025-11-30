# app/services/notification_service.rb
# 
# This service handles notification creation with background job support
# for faster response times. Notifications are queued and processed async.

class NotificationService
  class << self
    # ============================================================================
    # PROJECT NOTIFICATIONS
    # ============================================================================

    def project_created(project, created_by)
      enqueue_notification('project_created', {
        project_id: project.id,
        created_by_id: created_by.id
      })
    end

    def project_updated(project, updated_by, changes = {})
      enqueue_notification('project_updated', {
        project_id: project.id,
        updated_by_id: updated_by.id,
        changes: changes.as_json
      })
    end

    def project_status_changed(project, changed_by, old_status, new_status)
      enqueue_notification('project_status_changed', {
        project_id: project.id,
        changed_by_id: changed_by.id,
        old_status: old_status.to_s,
        new_status: new_status.to_s
      })
    end

    def project_progress_updated(project, updated_by, old_progress, new_progress, notes = nil)
      return if (new_progress - old_progress).abs < 5 # Skip small changes
      
      enqueue_notification('project_progress_updated', {
        project_id: project.id,
        updated_by_id: updated_by.id,
        old_progress: old_progress,
        new_progress: new_progress,
        notes: notes
      })
    end

    def project_completed(project, completed_by)
      enqueue_notification('project_completed', {
        project_id: project.id,
        completed_by_id: completed_by.id
      })
    end

    def project_deadline_approaching(project, days_left)
      enqueue_notification('project_deadline_approaching', {
        project_id: project.id,
        days_left: days_left
      })
    end

    def project_overdue(project)
      enqueue_notification('project_overdue', {
        project_id: project.id
      })
    end

    # ============================================================================
    # TENDER NOTIFICATIONS
    # ============================================================================

    def tender_created(tender, created_by)
      enqueue_notification('tender_created', {
        tender_id: tender.id,
        created_by_id: created_by.id
      })
    end

    def tender_updated(tender, updated_by, changes = {})
      enqueue_notification('tender_updated', {
        tender_id: tender.id,
        updated_by_id: updated_by.id,
        changes: changes.as_json
      })
    end

    def tender_status_changed(tender, changed_by, old_status, new_status)
      enqueue_notification('tender_status_changed', {
        tender_id: tender.id,
        changed_by_id: changed_by.id,
        old_status: old_status.to_s,
        new_status: new_status.to_s
      })
    end

    def tender_converted(tender, project, converted_by)
      enqueue_notification('tender_converted', {
        tender_id: tender.id,
        project_id: project.id,
        converted_by_id: converted_by.id
      })
    end

    def tender_deadline_approaching(tender, days_left)
      enqueue_notification('tender_deadline_approaching', {
        tender_id: tender.id,
        days_left: days_left
      })
    end

    # ============================================================================
    # TASK NOTIFICATIONS
    # ============================================================================

    def task_created(task, created_by)
      enqueue_notification('task_created', {
        task_id: task.id,
        created_by_id: created_by.id
      })
    end

    def task_assigned(task, assignee, assigned_by)
      enqueue_notification('task_assigned', {
        task_id: task.id,
        assignee_id: assignee.id,
        assigned_by_id: assigned_by.id
      })
    end

    def task_status_changed(task, changed_by, old_status, new_status)
      enqueue_notification('task_status_changed', {
        task_id: task.id,
        changed_by_id: changed_by.id,
        old_status: old_status.to_s,
        new_status: new_status.to_s
      })
    end

    def task_completed(task, completed_by)
      enqueue_notification('task_completed', {
        task_id: task.id,
        completed_by_id: completed_by.id
      })
    end

    def task_overdue(task)
      enqueue_notification('task_overdue', {
        task_id: task.id
      })
    end

    # ============================================================================
    # SYSTEM NOTIFICATIONS
    # ============================================================================

    def system_announcement(title:, message:, user_ids: nil, priority: 'medium')
      enqueue_notification('system_announcement', {
        title: title,
        message: message,
        user_ids: user_ids,
        priority: priority
      })
    end

    def welcome(user)
      enqueue_notification('welcome', {
        user_id: user.id
      })
    end

    # ============================================================================
    # SCHEDULED CHECKS (call from cron/scheduler)
    # ============================================================================

    def check_upcoming_deadlines
      # Projects due in 7 days
      Project.where(status: ['planning', 'in_progress'])
             .where('finishing_date BETWEEN ? AND ?', Date.current, 7.days.from_now)
             .find_each do |project|
        days_left = (project.finishing_date - Date.current).to_i
        project_deadline_approaching(project, days_left)
      end

      # Tenders due in 7 days
      Tender.where(status: 'active')
            .where('deadline BETWEEN ? AND ?', Date.current, 7.days.from_now)
            .find_each do |tender|
        days_left = (tender.deadline - Date.current).to_i
        tender_deadline_approaching(tender, days_left)
      end
    end

    def check_overdue_items
      Project.where(status: ['planning', 'in_progress'])
             .where('finishing_date < ?', Date.current)
             .find_each { |project| project_overdue(project) }

      Task.where.not(status: ['completed', 'cancelled'])
          .where('due_date < ?', Date.current)
          .find_each { |task| task_overdue(task) }
    end

    private

    # ============================================================================
    # ENQUEUE - Send to background job for async processing
    # ============================================================================

    def enqueue_notification(notification_type, payload)
      NotificationJob.perform_later(notification_type, payload)
    rescue => e
      Rails.logger.warn "NotificationJob unavailable, processing sync: #{e.message}"
      NotificationJob.new.perform(notification_type, payload)
    end
  end
end