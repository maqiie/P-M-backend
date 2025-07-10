class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :update, :destroy]

  # GET /tasks
  def index
    # Get tasks where current user is involved (as manager, owner, or assignee)
    @tasks = current_user.all_tasks.includes(:assignees, :project, :project_manager, :user)
    
    # Apply filters if provided
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
      @tasks = @tasks.where("title ILIKE ? OR description ILIKE ?", 
                           "%#{params[:search]}%", "%#{params[:search]}%")
    end
    
    render json: { 
      tasks: @tasks.as_json(include: {
        assignees: { only: [:id, :name, :email] },
        project: { only: [:id, :title] },
        project_manager: { only: [:id, :name, :email] },
        user: { only: [:id, :name, :email] }
      })
    }
  end

  # GET /tasks/:id
  def show
    render json: @task.as_json(include: {
      assignees: { only: [:id, :name, :email] },
      watchers: { only: [:id, :name, :email] },
      project: { only: [:id, :title] },
      project_manager: { only: [:id, :name, :email] },
      user: { only: [:id, :name, :email] }
    })
  end

  # POST /tasks
  def create
    @task = Task.new(task_params)
    @task.project_manager = current_user  # Current user is the project manager
    @task.user = current_user  # Current user is also the creator
    
    if @task.save
      # Handle assignees
      if params[:task][:assignee_ids].present?
        @task.assignees = User.where(id: params[:task][:assignee_ids])
      end
      
      # Handle watchers
      if params[:task][:watcher_ids].present?
        @task.watchers = User.where(id: params[:task][:watcher_ids])
      end
      
      # Handle custom fields if provided
      if params[:task][:custom_fields].present?
        @task.update(custom_fields: params[:task][:custom_fields])
      end
      
      render json: @task.as_json(include: {
        assignees: { only: [:id, :name, :email] },
        project: { only: [:id, :title] },
        project_manager: { only: [:id, :name, :email] }
      }), status: :created
    else
      render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /tasks/:id
  def update
    if @task.update(task_params)
      # Handle assignees
      if params[:task][:assignee_ids].present?
        @task.assignees = User.where(id: params[:task][:assignee_ids])
      end
      
      # Handle watchers
      if params[:task][:watcher_ids].present?
        @task.watchers = User.where(id: params[:task][:watcher_ids])
      end
      
      # Handle custom fields if provided
      if params[:task][:custom_fields].present?
        @task.update(custom_fields: params[:task][:custom_fields])
      end
      
      render json: @task.as_json(include: {
        assignees: { only: [:id, :name, :email] },
        project: { only: [:id, :title] },
        project_manager: { only: [:id, :name, :email] }
      })
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
    # Get tasks where current user is involved
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
  end

  def task_params
    params.require(:task).permit(
      :title, :description, :due_date, :start_date, :status, :priority,
      :estimated_hours, :project_id, tags: []
    )
  end
end