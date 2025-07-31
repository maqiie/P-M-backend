class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :update, :destroy]

  # GET /tasks
  def index
    # Get tasks where current user is involved (as manager, owner, or assignee)
    @tasks = current_user.all_tasks.includes(:assignees, :watchers, :project, :project_manager, :user)

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
    @task.project_manager = current_user  # Assign current user as project manager
    @task.user = current_user             # Assign current user as creator

    if @task.save
      # Assign assignees if provided
      if params[:task][:assignee_ids].present?
        @task.assignees = User.where(id: params[:task][:assignee_ids])
      end

      # Assign watchers if provided
      if params[:task][:watcher_ids].present?
        @task.watchers = User.where(id: params[:task][:watcher_ids])
      end

      # Update custom fields if provided
      if params[:task][:custom_fields].present?
        @task.update(custom_fields: params[:task][:custom_fields])
      end

      render json: task_json(@task), status: :created
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /tasks/:id
  def update
    if @task.update(task_params)
      # Update assignees if provided
      if params[:task][:assignee_ids].present?
        @task.assignees = User.where(id: params[:task][:assignee_ids])
      end

      # Update watchers if provided
      if params[:task][:watcher_ids].present?
        @task.watchers = User.where(id: params[:task][:watcher_ids])
      end

      # Update custom fields if provided
      if params[:task][:custom_fields].present?
        @task.update(custom_fields: params[:task][:custom_fields])
      end

      render json: task_json(@task)
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /tasks/:id
  def destroy
    @task.destroy
    render json: { message: 'Task deleted successfully' }
  end

  # GET /tasks/statistics
  def statistics
    user_tasks = current_user.all_tasks
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
    @task = current_user.all_tasks.find(params[:id])
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
