class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :progress, :update_progress, :progress_history, :progress_trends]

  def index
    @projects = Project.all
    render json: @projects
  end

   # GET /projects/active - NEW METHOD
   def active
    # Get active projects for current user
    @active_projects = current_user_projects.active.includes(:project_manager, :supervisor, :site_manager)
    
    # Apply filters
    @active_projects = @active_projects.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'
    @active_projects = @active_projects.where(priority: params[:priority]) if params[:priority].present? && params[:priority] != 'all'
    
    # Search functionality
    if params[:search].present?
      @active_projects = @active_projects.where(
        "title ILIKE ? OR description ILIKE ? OR location ILIKE ? OR lead_person ILIKE ?", 
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    # Format data for React component
    projects_data = @active_projects.map do |project|
      {
        id: project.id,
        name: project.title,
        client: project.responsible || project.lead_person || "Client Name",
        status: format_status_for_display(project.status),
        priority: format_priority_for_display(project.priority),
        progress: project.progress_percentage.to_f,
        budget: project.budget&.to_f || 0,
        spent: calculate_spent_amount(project),
        startDate: project.start_date&.strftime('%Y-%m-%d'),
        deadline: project.finishing_date&.strftime('%Y-%m-%d'),
        daysLeft: project.days_remaining,
        location: project.location || "Location TBD",
        nextMilestone: get_next_milestone_name(project),
        milestoneDate: get_next_milestone_date(project),
        recentActivity: get_recent_activity(project),
        risks: calculate_risk_count(project),
        isStarred: false, # Add this field to model later if needed
        description: project.description || "No description available",
        team: build_team_array(project),
        # Additional fields for detailed view
        milestones: build_milestones_array(project),
        documents: [], # Add document association later if needed
        recentUpdates: build_recent_updates(project)
      }
    end

    render json: { 
      projects: projects_data,
      total: @active_projects.count,
      filters: {
        statuses: Project.statuses.keys.map { |s| { value: s, label: format_status_for_display(s) } },
        priorities: Project.priorities.keys.map { |p| { value: p, label: format_priority_for_display(p) } }
      }
    }
  end

  # GET /projects/completed - BONUS METHOD
  def completed
    @completed_projects = current_user_projects.completed.includes(:project_manager, :supervisor, :site_manager)
    
    # Apply same filtering logic as active
    if params[:search].present?
      @completed_projects = @completed_projects.where(
        "title ILIKE ? OR description ILIKE ?", 
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    projects_data = @completed_projects.map do |project|
      {
        id: project.id,
        name: project.title,
        client: project.responsible || project.lead_person || "Client Name",
        status: format_status_for_display(project.status),
        priority: format_priority_for_display(project.priority),
        progress: project.progress_percentage.to_f,
        budget: project.budget&.to_f || 0,
        spent: calculate_spent_amount(project),
        completedDate: project.updated_at&.strftime('%Y-%m-%d'),
        location: project.location,
        description: project.description,
        team: build_team_array(project)
      }
    end

    render json: { 
      projects: projects_data,
      total: @completed_projects.count
    }
  end

  def chart_data
    @chart_data = Project
                   .select("DATE_TRUNC('month', created_at) AS month, COUNT(*) AS count")
                   .group(Arel.sql("DATE_TRUNC('month', created_at)"))
                   .order(Arel.sql("DATE_TRUNC('month', created_at)"))
                   .map { |data| [data.month.strftime("%Y-%m"), data.count] }

    render json: @chart_data
  end

  def create
    @project = Project.new(project_params)
    @project.project_manager_id = current_user.id

    if @project.save
      render json: @project, status: :created
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: @project
  end

  # GET /projects/:id/progress
  def progress
    timeline_progress = calculate_timeline_progress(@project)
    variance = @project.progress_percentage.to_f - timeline_progress
    schedule_status = determine_schedule_status(@project.progress_percentage.to_f, timeline_progress)

    render json: {
      id: @project.id,
      current_progress: @project.progress_percentage.to_f,
      timeline_progress: timeline_progress,
      progress_variance: variance,
      schedule_status: schedule_status,
      behind_schedule: schedule_status == 'behind_schedule',
      ahead_of_schedule: schedule_status == 'ahead_of_schedule',
      days_remaining: @project.days_remaining,
      estimated_completion: @project.estimated_completion_date
    }
  end

  # PATCH /projects/:id/update_progress
  def update_progress
    return unless @project

    new_progress = params[:progress_percentage].to_f
    notes = params[:notes]

    if new_progress < 0 || new_progress > 100
      render json: { success: false, message: 'Progress must be between 0 and 100' }, status: :unprocessable_entity
      return
    end

    timeline_progress = calculate_timeline_progress(@project)
    variance = new_progress - timeline_progress
    schedule_status = determine_schedule_status(new_progress, timeline_progress)
    warning = variance.abs > 30 ? "Warning: Progress is significantly off expected timeline progress." : nil

    ActiveRecord::Base.transaction do
      old_progress = @project.progress_percentage_was || 0

      @project.update!(
        progress_percentage: new_progress,
        progress_notes: notes,
        last_progress_update: Time.current
      )

      ProgressUpdate.create!(
        project: @project,
        old_progress: old_progress,
        new_progress: new_progress,
        notes: notes,
        updated_by_id: current_user.id,
        update_type: "manual",
        timeline_progress_at_update: timeline_progress,
        variance_at_update: variance,
        project_status_at_update: @project.status
      )
    end

    render json: {
      success: true,
      message: 'Progress updated successfully',
      project: {
        id: @project.id,
        progress_percentage: new_progress,
        timeline_progress: timeline_progress,
        progress_variance: variance,
        schedule_status: schedule_status
      },
      warning: warning
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, message: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Progress update failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: "An error occurred: #{e.message}" }, status: :unprocessable_entity
  end

  # GET /projects/:id/progress_history
  def progress_history
    progress = @project.progress_percentage.to_f

    render json: [
      {
        old_progress: [progress - 10, 0].max,
        new_progress: progress,
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
      average_progress: projects.average(:progress_percentage).to_f.round(2)
    }

    render json: summary
  end

  # GET /projects/:id/progress_trends
  def progress_trends
    updates = @project.progress_updates.order(created_at: :desc).limit(5)

    trend_data = updates.map do |update|
      {
        date: update.created_at.to_date,
        progress: update.new_progress,
        timeline_progress: update.timeline_progress_at_update,
        variance: update.variance_at_update
      }
    end.reverse

    trend = if trend_data.size >= 2
      trend_data.last[:variance] - trend_data.first[:variance]
    else
      0
    end

    schedule_trend = if trend > 0
      "catching_up"
    elsif trend < 0
      "falling_behind"
    else
      "stable"
    end

    render json: {
      project_id: @project.id,
      last_updates: trend_data,
      schedule_trend: schedule_trend
    }
  end

  private
  def format_status_for_display(status)
    case status.to_s
    when 'in_progress'
      'In Progress'
    when 'planning'
      'Planning'
    when 'at_risk'
      'At Risk'
    when 'on_hold'
      'On Hold'
    when 'completed'
      'Completed'
    when 'cancelled'
      'Cancelled'
    when 'review'
      'In Review'
    else
      status.to_s.humanize
    end
  end

  def format_priority_for_display(priority)
    case priority.to_s
    when 'low'
      'Low'
    when 'medium'
      'Medium'
    when 'high'
      'High'
    when 'critical'
      'Critical'
    else
      priority.to_s.humanize
    end
  end

  def calculate_spent_amount(project)
    # Calculate based on progress percentage as approximation
    # You can replace this with actual expense calculation later
    budget = project.budget&.to_f || 0
    (budget * project.progress_percentage.to_f / 100).round(2)
  end

  def get_next_milestone_name(project)
    # Try to get from events/milestones, fallback to status-based
    next_event = project.events.where('date > ?', Date.current).order(:date).first
    return next_event.description if next_event
    
    case project.status
    when 'planning'
      'Start Construction'
    when 'in_progress'
      'Next Phase Completion'
    when 'review'
      'Final Approval'
    else
      'Project Completion'
    end
  end

  def get_next_milestone_date(project)
    next_event = project.events.where('date > ?', Date.current).order(:date).first
    return next_event.date&.strftime('%Y-%m-%d') if next_event
    
    # Fallback to finishing date
    project.finishing_date&.strftime('%Y-%m-%d')
  end

  def get_recent_activity(project)
    recent_update = project.progress_updates.order(created_at: :desc).first
    return recent_update.notes if recent_update&.notes.present?
    
    project.progress_notes.presence || "Project #{project.progress_percentage.to_i}% complete"
  end

  def calculate_risk_count(project)
    risk_count = 0
    risk_count += 1 if project.behind_schedule?
    risk_count += 1 if project.overdue?
    risk_count += 1 if project.status == 'at_risk'
    risk_count
  end

  def build_team_array(project)
    team = []
    
    # Add project manager
    if project.project_manager
      team << {
        name: project.project_manager.name || 'Project Manager',
        role: 'Project Manager',
        avatar: get_avatar_initials(project.project_manager.name),
        id: project.project_manager.id
      }
    end
    
    # Add supervisor
    if project.supervisor
      team << {
        name: project.supervisor.name || 'Supervisor',
        role: 'Supervisor', 
        avatar: get_avatar_initials(project.supervisor.name),
        id: project.supervisor.id
      }
    end
    
    # Add site manager if exists
    if project.site_manager
      team << {
        name: project.site_manager.name || 'Site Manager',
        role: 'Site Manager',
        avatar: get_avatar_initials(project.site_manager.name),
        id: project.site_manager.id
      }
    end
    
    team
  end

  def get_avatar_initials(name)
    return 'U' unless name.present?
    name.split.map(&:first).join.upcase[0..1]
  end

  def build_milestones_array(project)
    # Create milestones based on project status
    milestones = [
      {
        name: 'Planning',
        status: project_milestone_status('planning', project.status),
        date: project.start_date&.strftime('%Y-%m-%d') || Date.current.strftime('%Y-%m-%d')
      },
      {
        name: 'Construction',
        status: project_milestone_status('in_progress', project.status),
        date: project.start_date ? (project.start_date + 30.days).strftime('%Y-%m-%d') : nil
      },
      {
        name: 'Review',
        status: project_milestone_status('review', project.status),
        date: project.finishing_date ? (project.finishing_date - 14.days).strftime('%Y-%m-%d') : nil
      },
      {
        name: 'Completion',
        status: project_milestone_status('completed', project.status),
        date: project.finishing_date&.strftime('%Y-%m-%d')
      }
    ]
    
    milestones.compact
  end

  def project_milestone_status(milestone_status, current_status)
    milestone_order = { 'planning' => 0, 'in_progress' => 1, 'review' => 2, 'completed' => 3 }
    current_order = milestone_order[current_status] || 0
    target_order = milestone_order[milestone_status] || 0
    
    if current_order > target_order
      'completed'
    elsif current_order == target_order
      'in_progress'
    else
      'pending'
    end
  end

  def build_recent_updates(project)
    updates = project.progress_updates.order(created_at: :desc).limit(3)
    
    updates.map do |update|
      {
        date: update.created_at.strftime('%Y-%m-%d'),
        update: update.notes || "Progress updated to #{update.new_progress}%",
        author: User.find(update.updated_by_id)&.name || 'System'
      }
    end
  end

  def current_user_projects
    # Return projects user manages or supervises
    if current_user.admin?
      Project.all
    else
      Project.where(
        'project_manager_id = ? OR supervisor_id = ?', 
        current_user.id, current_user.id
      )
    end
  end

  def project_params
    params.require(:project).permit(:title, :status, :supervisor_id, :location, :finishing_date, :lead_person, :start_date)
  end

  def set_project
    @project = current_user.managed_projects.lock(true).find_by(id: params[:id])
    unless @project
      render json: { error: "Project not found or not authorized" }, status: :not_found and return
    end
  end

  def current_user_projects
    if current_user.project_manager?
      current_user.managed_projects
    else
      Project.all
    end
  end

  def calculate_timeline_progress(project)
    return 0 unless project.finishing_date && project.start_date

    total_duration = (project.finishing_date.to_date - project.start_date.to_date).to_f
    elapsed_duration = (Date.current - project.start_date.to_date).to_f

    return 0 if total_duration <= 0

    progress = (elapsed_duration / total_duration) * 100
    progress = 0 if progress < 0
    progress = 100 if progress > 100
    progress.round(2)
  end

  def determine_schedule_status(actual_progress, timeline_progress, threshold = 5)
    diff = actual_progress - timeline_progress
    if diff.abs <= threshold
      'on_track'
    elsif diff < -threshold
      'behind_schedule'
    else
      'ahead_of_schedule'
    end
  end
end
