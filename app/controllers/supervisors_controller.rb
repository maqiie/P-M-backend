# app/controllers/supervisors_controller.rb

class SupervisorsController < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  before_action :authenticate_user!
  before_action :set_supervisor, only: [:show, :update, :destroy]
  
  def index
    @supervisors = Supervisor.all
    render json: @supervisors.map { |s| supervisor_json(s) }
  end
  
  def show
    render json: supervisor_json(@supervisor)
  end
  
  def create
    @supervisor = Supervisor.new(supervisor_params)
    
    if @supervisor.save
      render json: supervisor_json(@supervisor), status: :created
    else
      render json: { errors: @supervisor.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    if @supervisor.update(supervisor_params)
      render json: supervisor_json(@supervisor)
    else
      render json: { errors: @supervisor.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @supervisor.destroy
    head :no_content
  end
  
  def workload
    supervisors = Supervisor.all.map do |supervisor|
      {
        supervisor_name: supervisor.name,
        project_count: supervisor.projects.count # Assuming a Supervisor has_many :projects
      }
    end

    render json: supervisors
  end
  
  private
  
  def set_supervisor
    @supervisor = Supervisor.find(params[:id])
  end
  
  def supervisor_params
    params.require(:supervisor).permit(:name, :email)
  end
  
  def supervisor_json(supervisor)
    {
      id: supervisor.id,
      name: supervisor.name,
      email: supervisor.email,
      role: 'supervisor',
      projects_count: supervisor.projects.count,
      current_projects: supervisor.projects.pluck(:title),
      created_at: supervisor.created_at
    }
  end
  

end
    