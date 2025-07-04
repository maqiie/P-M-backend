class TasksController < ApplicationController
    before_action :set_task, only: [:show, :edit, :update, :destroy]
    before_action :authenticate_user!
  
    # Optional: restrict to project managers only
    before_action :require_project_manager
  
    def index
      @tasks = current_user.tasks
    end
  
    def show
    end
  
    def new
      @task = current_user.tasks.new
    end
  
    def create
      @task = current_user.tasks.new(task_params)
      if @task.save
        redirect_to @task, notice: 'Task was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end
  
    def edit
    end
  
    def update
      if @task.update(task_params)
        redirect_to @task, notice: 'Task was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end
  
    def destroy
      @task.destroy
      redirect_to tasks_path, notice: 'Task was successfully deleted.'
    end
  
    private
  
    def set_task
      @task = current_user.tasks.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to tasks_path, alert: 'Task not found.'
    end
  
    def task_params
      params.require(:task).permit(:title, :description, :due_date, :status)
    end
  
    def require_project_manager
      unless current_user&.user?
        redirect_to root_path, alert: 'Access denied. You must be a project manager.'
      end
    end
  end
  