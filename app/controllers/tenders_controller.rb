class TendersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tender, only: [:show, :update, :destroy, :convert_to_project, :update_status, :details]

  # ======================
  # INDEX / LIST
  # ======================
  def index
    @tenders = current_user.admin? ? Tender.includes(:project_manager, :project) : current_user.tenders.includes(:project_manager, :project)
    @tenders = @tenders.where(status: params[:status]) if params[:status].present?
    @tenders = @tenders.where(priority: params[:priority]) if params[:priority].present?
    @tenders = @tenders.where("title ILIKE ?", "%#{params[:search]}%") if params[:search].present?
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

  # ======================
  # CREATE
  # ======================
  def create
    @tender = current_user.tenders.build(tender_params)
    @tender.project_manager = current_user

    if @tender.save
      Activity.create!(
        actor: current_user,
        action: 'created',
        target: @tender,
        metadata: { tender_title: @tender.title }
      )

      NotificationService.tender_created(@tender, current_user) # ✅ Notify creation

      render json: {
        tender: tender_json(@tender),
        message: 'Tender created successfully',
        status: 'success'
      }, status: :created
    else
      render json: { errors: @tender.errors.full_messages, status: 'error' }, status: :unprocessable_entity
    end
  end

  # ======================
  # UPDATE
  # ======================
  def update
    old_status = @tender.status
    if @tender.update(tender_params)
      Activity.create!(
        actor: current_user,
        action: 'updated',
        target: @tender,
        metadata: { changes: @tender.previous_changes, notes: 'Tender updated' }
      )

      NotificationService.tender_updated(@tender, current_user, @tender.previous_changes) # ✅ Notify update

      # Notify if status changed
      if old_status != @tender.status
        NotificationService.tender_status_changed(@tender, current_user, old_status, @tender.status)
      end

      render json: {
        tender: tender_json(@tender),
        message: 'Tender updated successfully',
        status: 'success'
      }
    else
      render json: { errors: @tender.errors.full_messages, status: 'error' }, status: :unprocessable_entity
    end
  end

  # ======================
  # DELETE
  # ======================
  def destroy
    tender_info = @tender.attributes.slice("id", "title")
    @tender.destroy

    Activity.create!(
      actor: current_user,
      action: 'deleted',
      target_type: 'Tender',
      target_id: tender_info["id"],
      metadata: { tender_title: tender_info["title"] }
    )

    # Optional: create a notification on deletion
    # NotificationService.tender_deleted(@tender, current_user)

    render json: {
      message: 'Tender deleted successfully',
      status: 'success'
    }
  end

  # ======================
  # CONVERT TO PROJECT
  # ======================
  def convert_to_project
    @project = Project.new(
      title: @tender.title,
      description: @tender.description,
      project_manager_id: @tender.project_manager_id || current_user.id,
      supervisor_id: params[:supervisor_id] || @tender.project_manager_id || current_user.id,
      user_id: current_user.id,
      lead_person: @tender.lead_person,
      responsible: @tender.responsible,
      location: @tender.location || 'TBD',
      start_date: params[:start_date],
      finishing_date: params[:finishing_date],
      budget: @tender.budget_estimate,
      status: 0,
      priority: 1
    )

    if @project.save
      @tender.update(project_id: @project.id, status: 'converted')
      Activity.create!(
        actor: current_user,
        action: 'converted',
        target: @tender,
        metadata: { new_project_id: @project.id, notes: 'Tender converted to project' }
      )

      NotificationService.tender_converted(@tender, @project, current_user) # ✅ Notify conversion

      render json: {
        project: project_json(@project),
        tender: tender_json(@tender),
        message: 'Tender successfully converted to project',
        status: 'success'
      }
    else
      render json: { errors: @project.errors.full_messages, status: 'error' }, status: :unprocessable_entity
    end
  end

  # ======================
  # UPDATE STATUS
  # ======================
  def update_status
    old_status = @tender.status
    if @tender.update(status: params[:status])
      Activity.create!(
        actor: current_user,
        action: 'status_updated',
        target: @tender,
        metadata: { changes: { status: [old_status, @tender.status] }, notes: 'Tender status updated' }
      )

      NotificationService.tender_status_changed(@tender, current_user, old_status, @tender.status) # ✅ Notify status change

      render json: { tender: tender_json(@tender), message: "Tender status updated to #{params[:status]}", status: 'success' }
    else
      render json: { errors: @tender.errors.full_messages, status: 'error' }, status: :unprocessable_entity
    end
  end

  # ======================
  # OTHER ACTIONS
  # ======================
  def details
    render json: { tender: tender_json(@tender, include_details: true), status: 'success' }
  end

  def active
    @tenders = current_user.tenders.active.by_deadline
    render json: { tenders: @tenders.map { |t| tender_json(t) }, total: @tenders.count, status: 'success' }
  end

  def urgent
    @tenders = current_user.tenders.urgent.by_deadline
    render json: { tenders: @tenders.map { |t| tender_json(t) }, total: @tenders.count, status: 'success' }
  end

  def drafts
    @tenders = current_user.tenders.where(status: 'draft').recent
    render json: { tenders: @tenders.map { |t| tender_json(t) }, total: @tenders.count, status: 'success' }
  end

  def statistics
    @tenders = current_user.tenders
    today = Date.current

    stats = {
      total: @tenders.count,
      active: @tenders.where(status: 'active').count,
      draft: @tenders.where(status: 'draft').count,
      completed: @tenders.where(status: 'completed').count,
      rejected: @tenders.where(status: 'rejected').count,
      converted: @tenders.where(status: 'converted').count,
      urgent: @tenders.joins("LEFT JOIN (SELECT id FROM tenders WHERE deadline <= '#{7.days.from_now.to_date}' AND status = 'active') AS urgent_tenders ON tenders.id = urgent_tenders.id").where.not(urgent_tenders: { id: nil }).count,
      expired: @tenders.where('deadline < ? AND status NOT IN (?)', today, ['completed', 'converted', 'rejected']).count,
      totalValue: @tenders.sum(:budget_estimate) || 0,
      avgSubmissions: @tenders.count > 0 ? (@tenders.sum(:submission_count).to_f / @tenders.count).round(2) : 0
    }

    render json: { statistics: stats, status: 'success' }
  end

  private

  # ======================
  # SETTERS / STRONG PARAMS
  # ======================
  def set_tender
    @tender = current_user.tenders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tender not found', status: 'error' }, status: :not_found
  end

  def tender_params
    params.require(:tender).permit(
      :title, :description, :deadline, :lead_person, :responsible, 
      :project_id, :project_manager_id, :status, :priority, :category,
      :location, :client, :budget_estimate, :estimated_duration,
      requirements: []
    )
  end

  # ======================
  # SERIALIZERS
  # ======================
  def tender_json(tender, include_details: false)
    # Keep your existing serialization logic
    base_data = {
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
      days_remaining: tender.respond_to?(:days_remaining) ? tender.days_remaining : calculate_days_remaining(tender.deadline),
      expired: tender.respond_to?(:expired?) ? tender.expired? : calculate_expired(tender.deadline),
      urgent: tender.respond_to?(:urgent?) ? tender.urgent? : calculate_urgent(tender.deadline),
      status_color: tender.respond_to?(:status_color) ? tender.status_color : get_status_color(tender.status),
      project_manager: {
        id: tender.project_manager&.id,
        name: tender.project_manager&.name,
        email: tender.project_manager&.email
      }
    }

    if include_details
      base_data.merge!({
        full_description: tender.description,
        detailed_requirements: tender.requirements,
        submission_details: {
          count: tender.submission_count || 0,
          last_submission_date: tender.updated_at
        }
      })
    end

    base_data
  end

  def project_json(project)
    {
      id: project.id,
      title: project.title,
      description: project.description,
      status: project.status,
      progress: project.respond_to?(:progress_percentage) ? project.progress_percentage : 0
    }
  end

  def calculate_days_remaining(deadline)
    return nil unless deadline
    (deadline.to_date - Date.current).to_i
  end

  def calculate_expired(deadline)
    return false unless deadline
    deadline.to_date < Date.current
  end

  def calculate_urgent(deadline)
    return false unless deadline
    days = calculate_days_remaining(deadline)
    days && days <= 7 && days >= 0
  end

  def get_status_color(status)
    case status
    when 'active' then 'green'
    when 'draft' then 'yellow'
    when 'completed' then 'blue'
    when 'rejected' then 'red'
    when 'converted' then 'purple'
    else 'gray'
    end
  end
end
