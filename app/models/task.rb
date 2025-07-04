class Task < ApplicationRecord
  belongs_to :project_manager, class_name: 'User'

  enum status: { pending: 0, in_progress: 1, completed: 2 }
end
