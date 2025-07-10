class TendersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tender, only: [:show, :update, :destroy, :convert_to_project, :update_status, :details]

  def index
    @tenders = current_user.tenders.includes(:project_manager, :project)
    
    # Apply filters if provided
    @tenders = @tenders.where(status: params[:status]) if params[:status].present?
    @tenders = @tenders.where(priority: params[:priority]) if params[:priority].present?
    @tenders = @tenders.where("title ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    
    # Apply sorting
    @tenders = @tenders.by_deadline
    
    render json: {
      tenders: @tenders.map { |tender| tender_json(tender) },
      total: @tenders.count,
      status: 'success'
    }
  end

  def show
    render json: {
      tender: tender_json(@tender),
      status: 'success'
    }
  end

  def create
    @tender = current_user.tenders.build(tender_params)
    @tender.project_manager = current_user
    
    if @tender.save
      render json: {
        tender: tender_json(@tender),
        message: 'Tender created successfully',
        status: 'success'
      }, status: :created
    else
      render json: {
        errors: @tender.errors.full_messages,
        status: 'error'
      }, status: :unprocessable_entity
    end
  end

  def update
    if @tender.update(tender_params)
      render json: {
        tender: tender_json(@tender),
        message: 'Tender updated successfully',
        status: 'success'
      }
    else
      render json: {
        errors: @tender.errors.full_messages,
        status: 'error'
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @tender.destroy
    render json: {
      message: 'Tender deleted successfully',
      status: 'success'
    }
  end

  def convert_to_project
    @project = Project.new(
      title: @tender.title,
      description: @tender.description,
      deadline: @tender.deadline,
      project_manager_id: @tender.project_manager_id,
      lead_person: @tender.lead_person,
      responsible: @tender.responsible,
      location: @tender.location || 'TBD',
      finishing_date: @tender.deadline
    )

    if @project.save
      @tender.update(project_id: @project.id, status: 'converted')
      
      render json: {
        project: project_json(@project),
        tender: tender_json(@tender),
        message: 'Tender successfully converted to project',
        status: 'success'
      }
    else
      render json: {
        errors: @project.errors.full_messages,
        status: 'error'
      }, status: :unprocessable_entity
    end
  end

  # Specific endpoints for filtering
  def active
    @tenders = current_user.tenders.active.by_deadline
    render json: {
      tenders: @tenders.map { |tender| tender_json(tender) },
      total: @tenders.count,
      status: 'success'
    }
  end

  def urgent
    @tenders = current_user.tenders.urgent.by_deadline
    render json: {
      tenders: @tenders.map { |tender| tender_json(tender) },
      total: @tenders.count,
      status: 'success'
    }
  end

  def drafts
    @tenders = current_user.tenders.where(status: 'draft').recent
    render json: {
      tenders: @tenders.map { |tender| tender_json(tender) },
      total: @tenders.count,
      status: 'success'
    }
  end

  def my_tenders
    index # Alias for index - for compatibility with frontend
  end

  private

  def set_tender
    @tender = current_user.tenders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: 'Tender not found',
      status: 'error'
    }, status: :not_found
  end

  def tender_params
    params.require(:tender).permit(
      :title, :description, :deadline, :lead_person, :responsible, 
      :project_id, :project_manager_id, :status, :priority, :category,
      :location, :client, :budget_estimate, :estimated_duration,
      requirements: []
    )
  end

  def tender_json(tender, include_details: false)
    {
      id: tender.id,
      title: tender.title,
      description: tender.description,
      deadline: tender.deadline&.strftime('%Y-%m-%d'),
      created_date: tender.created_at&.strftime('%Y-%m-%d'),
      status: tender.status,
      priority: tender.priority || 'medium',
      category: tender.category || 'General',
      location: tender.location || 'TBD',
      client: tender.client || 'Internal',
      responsible: tender.responsible,
      lead_person: tender.lead_person,
      project_manager_id: tender.project_manager_id,
      project_id: tender.project_id,
      budget_estimate: tender.budget_estimate || 0,
      estimated_duration: tender.estimated_duration || 'TBD',
      requirements: tender.requirements || [],
      submission_count: tender.submission_count || 0,
      
      # Calculated fields
      days_remaining: tender.days_remaining,
      expired: tender.expired?,
      urgent: tender.urgent?,
      status_color: tender.status_color,
      
      # Associations
      project_manager: {
        id: tender.project_manager&.id,
        name: tender.project_manager&.name,
        email: tender.project_manager&.email
      }
    }
  end

  def project_json(project)
    {
      id: project.id,
      title: project.title,
      description: project.description,
      status: project.status,
      progress: project.progress_percentage || 0
    }
  end
end