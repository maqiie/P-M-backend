class ProjectsController < ApplicationController
    before_action :authenticate_user!

    def index
        @projects= Project.all
        render json: @projects
        

    end


def chart_data
  # Assuming you want to group by month and count records
  @chart_data = Project
                 .select("DATE_TRUNC('month', created_at) AS month, COUNT(*) AS count")
                 .group(Arel.sql("DATE_TRUNC('month', created_at)"))
                 .order(Arel.sql("DATE_TRUNC('month', created_at)"))
                 .map { |data| [data.month.strftime("%Y-%m"), data.count] }
  
  render json: @chart_data
end

    
    
  
    def create
        @project = Project.new(project_params)
        @project.project_manager_id = current_user.id  # Assuming `current_user` method provides the current logged-in user
    
        if @project.save
          # Render the created project as JSON if successful
          render json: @project, status: :created
        else
          # Render errors as JSON if saving the project fails
          render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
        end
      end
  
    def show
      @project = Project.find(params[:id])
    end
    # GET /projects/:id/progress
  def progress
    render json: {
      id: @project.id,
      current_progress: @project.progress_percentage_value || 0,
      timeline_progress: @project.timeline_progress_percentage,
      progress_variance: @project.progress_variance,
      schedule_status: @project.schedule_status,
      behind_schedule: @project.behind_schedule?,
      ahead_of_schedule: @project.ahead_of_schedule?,
      days_remaining: @project.days_remaining,
      estimated_completion: @project.estimated_completion_date
    }
  end

  # PATCH /projects/:id/update_progress
  def update_progress
    begin
      new_progress = params[:progress_percentage].to_f
      notes = params[:notes]
      
      # Update project progress in database
      @project.update!(
        progress_percentage_value: new_progress,
        progress_notes: notes,
        last_progress_update: Time.current
      )
      
      render json: {
        success: true,
        message: 'Progress updated successfully',
        project: {
          id: @project.id,
          progress_percentage: new_progress,
          timeline_progress: @project.timeline_progress_percentage,
          progress_variance: @project.progress_variance,
          schedule_status: @project.schedule_status
        }
      }
    rescue => e
      render json: { success: false, message: e.message }, status: 422
    end
  end

  # GET /projects/:id/progress_history
  def progress_history
    # Mock history for now - you can implement actual progress_updates table later
    render json: [
      {
        old_progress: [@project.progress_percentage_value - 10, 0].max,
        new_progress: @project.progress_percentage_value || 0,
        notes: @project.progress_notes || "Progress updated",
        created_at: @project.last_progress_update || @project.updated_at,
        updated_by: current_user.name
      }
    ]
  end

  # GET /projects/progress_summary
  def progress_summary
    projects = current_user_projects
    
    summary = {
      total_projects: projects.count,
      on_track: projects.select { |p| p.schedule_status == 'on_track' }.count,
      behind_schedule: projects.select { |p| p.behind_schedule? }.count,
      ahead_of_schedule: projects.select { |p| p.ahead_of_schedule? }.count,
      average_progress: projects.average(:progress_percentage_value) || 0
    }
    
    render json: summary
  end
  
    private
    def month_number(month_name)
      Date::MONTHNAMES.index(month_name)
    end
    def project_params
      params.require(:project).permit(:title, :status, :supervisor_id, :location, :finishing_date, :lead_person)
    end
    def set_project
      @project = current_user_projects.find(params[:id])
    end
  
    def current_user_projects
      # Get projects where user is project manager, supervisor, or has access
      Project.where(project_manager: current_user)
             .or(Project.where(supervisor: current_user))
             .or(Project.where(user: current_user))
    end
  end
  