class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :update, :destroy]

  # GET /tasks
  def index
    # Admin sees ALL tasks, regular users see only their tasks
    if current_user.admin?
      @tasks = Task.includes(:assignees, :watchers, :project, :project_manager, :user)
    else
      @tasks = current_user.all_tasks.includes(:assignees, :watchers, :project, :project_manager, :user)
    end

    # Filters
    @tasks = @tasks.where(status: Task.statuses[params[:status]]) if params[:status].present? && Task.statuses.key?(params[:status])
    @tasks = @tasks.where(priority: params[:priority]) if params[:priority].present?
    @tasks = @tasks.where(project_id: params[:project_id]) if params[:project_id].present?

    # Special filters
    case params[:filter]
    when 'active'
      @tasks = @tasks.active
    when 'overdue'
      @tasks = @tasks.overdue
    when 'due_today'
      @tasks = @tasks.due_today
    end

    # Search
    if params[:search].present?
      @tasks = @tasks.where("title ILIKE ? OR description ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    # Order: overdue first, then by due date ascending, nulls last
    @tasks = @tasks.order(Arel.sql('CASE WHEN due_date IS NULL THEN 1 ELSE 0 END, due_date ASC'))

    render json: {
      tasks: @tasks.map { |task| task_json(task) }
    }
  end

  # GET /tasks/:id
  def show
    render json: task_json(@task)
  end

  # POST /tasks
  def create
    @task = Task.new(task_params)
    @task.project_manager = current_user
    @task.user = current_user

    if @task.save
      @task.assignees = User.where(id: params[:task][:assignee_ids]) if params[:task][:assignee_ids].present?
      @task.watchers = User.where(id: params[:task][:watcher_ids]) if params[:task][:watcher_ids].present?
      @task.update(custom_fields: params[:task][:custom_fields]) if params[:task][:custom_fields].present?

      NotificationService.task_created(@task, current_user)

      render json: task_json(@task), status: :created
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /tasks/:id
  def update
    old_status = @task.status

    if @task.update(task_params)
      @task.assignees = User.where(id: params[:task][:assignee_ids]) if params[:task][:assignee_ids].present?
      @task.watchers = User.where(id: params[:task][:watcher_ids]) if params[:task][:watcher_ids].present?
      @task.update(custom_fields: params[:task][:custom_fields]) if params[:task][:custom_fields].present?

      NotificationService.task_updated(@task, current_user)
      NotificationService.task_status_changed(@task, current_user, old_status, @task.status) if old_status != @task.status

      render json: task_json(@task)
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /tasks/:id
  def destroy
    @task.destroy
    NotificationService.task_deleted(@task, current_user)
    render json: { message: 'Task deleted successfully' }
  end

  # GET /tasks/statistics
  def statistics
    if current_user.admin?
      user_tasks = Task.all
    else
      user_tasks = current_user.all_tasks
    end

    today = Date.current

    stats = {
      total: user_tasks.count,
      completed: user_tasks.completed.count,
      pending: user_tasks.pending.count,
      in_progress: user_tasks.in_progress.count,
      overdue: user_tasks.where('due_date < ? AND status NOT IN (?)', today, [Task.statuses[:completed], Task.statuses[:cancelled]]).count
    }

    render json: { statistics: stats }
  end

  private

  def set_task
    if current_user.admin?
      @task = Task.find(params[:id])
    else
      @task = current_user.all_tasks.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Task not found or not authorized' }, status: :not_found
  end

  def task_params
    params.require(:task).permit(
      :title, :description, :due_date, :start_date, :status, :priority,
      :estimated_hours, :project_id, tags: []
    )
  end

  def task_json(task)
    {
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      due_date: task.due_date&.strftime('%Y-%m-%d'),
      start_date: task.start_date&.strftime('%Y-%m-%d'),
      estimated_hours: task.estimated_hours,
      project: task.project ? { id: task.project.id, title: task.project.title } : nil,
      project_manager: task.project_manager ? { id: task.project_manager.id, name: task.project_manager.name, email: task.project_manager.email } : nil,
      user: task.user ? { id: task.user.id, name: task.user.name, email: task.user.email } : nil,
      assignees: task.assignees.map { |u| { id: u.id, name: u.name, email: u.email } },
      watchers: task.watchers.map { |u| { id: u.id, name: u.name, email: u.email } }
    }
  end
end