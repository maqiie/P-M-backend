class NotificationProcessor
  class << self
    def process(type, payload)
      case type
      when 'project_created'
        notify_admins(type, payload)
      when 'project_updated'
        notify_admins(type, payload)
      when 'tender_created'
        notify_admins(type, payload)
      when 'task_assigned'
        notify_user(payload[:assignee_id], type, payload)
      when 'system_announcement'
        notify_multiple_users(type, payload)
      else
        Rails.logger.warn "Unknown notification type: #{type}"
      end
    end

    private

    def notify_admins(type, payload)
      User.where(role: 'admin').find_each do |admin|
        Notification.create!(
          user: admin,
          notification_type: type,
          payload: payload
        )
      end
    end

    def notify_user(user_id, type, payload)
      return unless user_id

      Notification.create!(
        user_id: user_id,
        notification_type: type,
        payload: payload
      )
    end

    def notify_multiple_users(type, payload)
      if payload[:user_ids].present?
        payload[:user_ids].each do |uid|
          Notification.create!(
            user_id: uid,
            notification_type: type,
            payload: payload.except(:user_ids)
          )
        end
      else
        # Broadcast to all users
        User.find_each do |user|
          Notification.create!(
            user: user,
            notification_type: type,
            payload: payload.except(:user_ids)
          )
        end
      end
    end
  end
end
