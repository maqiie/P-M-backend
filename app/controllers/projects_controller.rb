class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [
    :show, 
    :update, 
    :destroy,
    :progress, 
    :update_progress, 
    :progress_history, 
    :progress_trends,
    :mark_as_completed
  ]

  # ============================================================================
  # INDEX / LIST ACTIONS
  # ============================================================================

  # GET /projects
  def index
    @projects = fetch_user_projects
    @projects = apply_filters(@projects)
    @projects = apply_search(@projects)
    
    projects_data = @projects.map { |project| format_project_for_list(project) }

    render json: { 
      projects: projects_data,
      total: @projects.count,
      is_admin_view: current_user.admin?
    }
  end

  # GET /projects/active
  def active
    @projects = fetch_user_projects.active
    @projects = apply_filters(@projects)
    @projects = apply_search(@projects)

    projects_data = @projects.map { |project| format_project_for_active(project) }

    render json: { 
      projects: projects_data,
      total: @projects.count,
      filters: available_filters
    }
  end

  # GET /projects/completed
  def completed
    @projects = fetch_user_projects.completed
    @projects = apply_search(@projects)

    projects_data = @projects.map { |project| format_project_for_completed(project) }

    render json: { 
      projects: projects_data,
      total: @projects.count
    }
  end

  # ============================================================================
  # CRUD ACTIONS
  # ============================================================================

  # GET /projects/:id
  def show
    render json: {
      project: format_project_detail(@project),
      status: 'success'
    }
  end

  # POST /projects
  def create
    @project = Project.new(project_params)
    @project.project_manager_id = current_user.id
    @project.user_id = current_user.id

    if @project.save
      log_activity("created", target: @project, metadata: { notes: "Project created by #{current_user.name}" })
      NotificationService.project_created(@project, current_user)  # ✅ Notify users

      render json: {
        project: format_project_detail(@project),
        message: 'Project created successfully',
        status: 'success'
      }, status: :created
    else
      render json: { 
        errors: @project.errors.full_messages,
        status: 'error'
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /projects/:id
  def update
    if @project.update(project_params)
      log_activity("updated", target: @project, metadata: { 
        changes: @project.previous_changes,
        notes: "Project updated by #{current_user.name}" 
      })
      NotificationService.project_updated(@project, current_user)  # ✅ Notify users

      render json: {
        project: format_project_detail(@project),
        message: 'Project updated successfully',
        status: 'success'
      }
    else
      render json: { 
        errors: @project.errors.full_messages,
        status: 'error'
      }, status: :unprocessable_entity
    end
  end

  # DELETE /projects/:id
  def destroy
    project_info = @project.attributes.slice("id", "title")
    
    if @project.destroy
      log_activity("deleted", target_type: 'Project', target_id: project_info["id"], 
                   metadata: { project_title: project_info["title"] })
      NotificationService.project_deleted(@project, current_user)  # ✅ Notify users

      render json: {
        message: 'Project deleted successfully',
        status: 'success'
      }
    else
      render json: {
        errors: @project.errors.full_messages,
        status: 'error'
      }, status: :unprocessable_entity
    end
  end

  # ============================================================================
  # PROGRESS ACTIONS
  # ============================================================================

  # GET /projects/:id/progress
  def progress
    timeline_progress = calculate_timeline_progress(@project)
    actual_progress = @project.progress_percentage.to_f
    variance = actual_progress - timeline_progress
    schedule_status = determine_schedule_status(actual_progress, timeline_progress)

    render json: {
      id: @project.id,
      title: @project.title,
      current_progress: actual_progress,
      timeline_progress: timeline_progress,
      progress_variance: variance.round(2),
      schedule_status: schedule_status,
      behind_schedule: schedule_status == 'behind_schedule',
      ahead_of_schedule: schedule_status == 'ahead_of_schedule',
      on_track: schedule_status == 'on_track',
      days_remaining: @project.days_remaining,
      start_date: @project.start_date&.strftime('%Y-%m-%d'),
      finishing_date: @project.finishing_date&.strftime('%Y-%m-%d'),
      estimated_completion: @project.estimated_completion_date&.strftime('%Y-%m-%d'),
      last_progress_update: @project.last_progress_update,
      progress_notes: @project.progress_notes,
      status: 'success'
    }
  end

  # PATCH /projects/:id/update_progress
  def update_progress
    new_progress = params[:progress_percentage].to_f
    notes = params[:notes]

    if new_progress < 0 || new_progress > 100
      render json: { 
        success: false, 
        message: 'Progress must be between 0 and 100' 
      }, status: :unprocessable_entity
      return
    end

    timeline_progress = calculate_timeline_progress(@project)
    variance = new_progress - timeline_progress
    schedule_status = determine_schedule_status(new_progress, timeline_progress)
    warning = variance.abs > 30 ? "Warning: Progress is significantly off expected timeline progress." : nil

    ActiveRecord::Base.transaction do
      old_progress = @project.progress_percentage || 0

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

      log_activity("progress_updated", target: @project, metadata: {
        old_progress: old_progress,
        new_progress: new_progress,
        notes: notes
      })

      NotificationService.project_progress_updated(@project, current_user, old_progress, new_progress) # ✅ Notify users
    end

    render json: {
      success: true,
      message: 'Progress updated successfully',
      project: {
        id: @project.id,
        progress_percentage: new_progress,
        timeline_progress: timeline_progress,
        progress_variance: variance.round(2),
        schedule_status: schedule_status
      },
      warning: warning
    }

  rescue ActiveRecord::RecordInvalid => e
    render json: { 
      success: false, 
      message: e.record.errors.full_messages.join(', ') 
    }, status: :unprocessable_entity
  end

  # GET /projects/:id/progress_history
  def progress_history
    updates = @project.progress_updates
                      .includes(:updated_by)
                      .order(created_at: :desc)
                      .limit(params[:limit] || 20)

    history_data = updates.map do |update|
      {
        id: update.id,
        old_progress: update.old_progress,
        new_progress: update.new_progress,
        change: update.new_progress - update.old_progress,
        notes: update.notes,
        timeline_progress: update.timeline_progress_at_update,
        variance: update.variance_at_update,
        project_status: update.project_status_at_update,
        update_type: update.update_type,
        updated_by: update.updated_by&.name || 'System',
        updated_by_id: update.updated_by_id,
        created_at: update.created_at,
        formatted_date: update.created_at.strftime('%Y-%m-%d %H:%M')
      }
    end

    render json: {
      project_id: @project.id,
      project_title: @project.title,
      current_progress: @project.progress_percentage.to_f,
      history: history_data,
      total: updates.count,
      status: 'success'
    }
  end

  # GET /projects/:id/progress_trends
  def progress_trends
    updates = @project.progress_updates
                      .order(created_at: :asc)
                      .limit(params[:limit] || 30)

    trend_data = updates.map do |update|
      {
        date: update.created_at.strftime('%Y-%m-%d'),
        timestamp: update.created_at,
        progress: update.new_progress,
        timeline_progress: update.timeline_progress_at_update,
        variance: update.variance_at_update
      }
    end

    schedule_trend = calculate_schedule_trend(trend_data)
    velocity = calculate_progress_velocity(updates)

    render json: {
      project_id: @project.id,
      project_title: @project.title,
      current_progress: @project.progress_percentage.to_f,
      trend_data: trend_data,
      schedule_trend: schedule_trend,
      velocity: velocity,
      projected_completion: calculate_projected_completion(@project, velocity),
      status: 'success'
    }
  end

  # GET /projects/progress_summary
  def progress_summary
    projects = fetch_user_projects

    on_track = projects.select { |p| determine_schedule_status(p.progress_percentage.to_f, calculate_timeline_progress(p)) == 'on_track' }
    behind = projects.select { |p| determine_schedule_status(p.progress_percentage.to_f, calculate_timeline_progress(p)) == 'behind_schedule' }
    ahead = projects.select { |p| determine_schedule_status(p.progress_percentage.to_f, calculate_timeline_progress(p)) == 'ahead_of_schedule' }

    summary = {
      total_projects: projects.count,
      on_track: on_track.count,
      behind_schedule: behind.count,
      ahead_of_schedule: ahead.count,
      average_progress: projects.average(:progress_percentage).to_f.round(2),
      projects_at_risk: behind.map { |p| { id: p.id, title: p.title, progress: p.progress_percentage.to_f } },
      status: 'success'
    }

    render json: summary
  end

  # ============================================================================
  # STATUS ACTIONS
  # ============================================================================

  # PATCH /projects/:id/mark_as_completed
  def mark_as_completed
    if @project.update(status: 'completed', progress_percentage: 100)
      log_activity("marked_as_completed", target: @project, metadata: { notes: "Marked as completed by #{current_user.name}" })
      NotificationService.project_completed(@project, current_user) # ✅ Notify users

      render json: {
        success: true,
        message: "Project marked as completed",
        project: format_project_detail(@project)
      }
    else
      render json: {
        success: false,
        errors: @project.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # ============================================================================
  # STATISTICS & CHARTS
  # ============================================================================

  # GET /projects/chart_data
  def chart_data
    @chart_data = Project
      .select("DATE_TRUNC('month', created_at) AS month, COUNT(*) AS count")
      .group(Arel.sql("DATE_TRUNC('month', created_at)"))
      .order(Arel.sql("DATE_TRUNC('month', created_at)"))
      .map { |data| { month: data.month.strftime("%Y-%m"), count: data.count } }

    render json: {
      chart_data: @chart_data,
      status: 'success'
    }
  end

  # GET /projects/statistics
  def statistics
    projects = fetch_user_projects

    stats = {
      total: projects.count,
      by_status: {
        planning: projects.where(status: 'planning').count,
        in_progress: projects.where(status: 'in_progress').count,
        on_hold: projects.where(status: 'on_hold').count,
        completed: projects.where(status: 'completed').count,
        cancelled: projects.where(status: 'cancelled').count,
        at_risk: projects.where(status: 'at_risk').count
      },
      by_priority: {
        low: projects.where(priority: 0).count,
        medium: projects.where(priority: 1).count,
        high: projects.where(priority: 2).count
      },
      total_budget: projects.sum(:budget).to_f,
      average_progress: projects.average(:progress_percentage).to_f.round(2),
      overdue: projects.where('finishing_date < ? AND status NOT IN (?)', Date.current, ['completed', 'cancelled']).count,
      due_this_week: projects.where(finishing_date: Date.current..1.week.from_now).count,
      due_this_month: projects.where(finishing_date: Date.current..1.month.from_now).count
    }

    render json: {
      statistics: stats,
      status: 'success'
    }
  end

  # ============================================================================
  # PRIVATE METHODS
  # ============================================================================

  private

  def set_project
    @project = fetch_user_projects.find_by(id: params[:id])
    
    unless @project
      render json: { 
        error: "Project not found or not authorized",
        status: 'error'
      }, status: :not_found
      return
    end
  end

  def fetch_user_projects
    base_query = if current_user.admin?
      Project.all
    else
      Project.where(
        'project_manager_id = ? OR supervisor_id = ? OR site_manager_id = ? OR user_id = ?',
        current_user.id, current_user.id, current_user.id, current_user.id
      )
    end

    base_query.includes(:project_manager, :supervisor, :site_manager)
  end

  def apply_filters(projects)
    projects = projects.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'
    projects = projects.where(priority: params[:priority]) if params[:priority].present? && params[:priority] != 'all'
    projects
  end

  def apply_search(projects)
    return projects unless params[:search].present?

    search_term = "%#{params[:search]}%"
    projects.where(
      "title ILIKE ? OR description ILIKE ? OR location ILIKE ? OR lead_person ILIKE ?",
      search_term, search_term, search_term, search_term
    )
  end

  def available_filters
    {
      statuses: Project.statuses.keys.map { |s| { value: s, label: format_status_for_display(s) } },
      priorities: Project.priorities.keys.map { |p| { value: p, label: format_priority_for_display(p) } }
    }
  end

 

  private

  # --------------------------------------------------------------------------
  # Before Action Callbacks
  # --------------------------------------------------------------------------

  def set_project
    @project = fetch_user_projects.find_by(id: params[:id])
    
    unless @project
      render json: { 
        error: "Project not found or not authorized",
        status: 'error'
      }, status: :not_found
      return
    end
  end

  # --------------------------------------------------------------------------
  # Project Fetching & Filtering
  # --------------------------------------------------------------------------

  def fetch_user_projects
    base_query = if current_user.admin?
      Project.all
    else
      Project.where(
        'project_manager_id = ? OR supervisor_id = ? OR site_manager_id = ? OR user_id = ?',
        current_user.id, current_user.id, current_user.id, current_user.id
      )
    end

    base_query.includes(:project_manager, :supervisor, :site_manager)
  end

  def apply_filters(projects)
    projects = projects.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'
    projects = projects.where(priority: params[:priority]) if params[:priority].present? && params[:priority] != 'all'
    projects
  end

  def apply_search(projects)
    return projects unless params[:search].present?

    search_term = "%#{params[:search]}%"
    projects.where(
      "title ILIKE ? OR description ILIKE ? OR location ILIKE ? OR lead_person ILIKE ?",
      search_term, search_term, search_term, search_term
    )
  end

  def available_filters
    {
      statuses: Project.statuses.keys.map { |s| { value: s, label: format_status_for_display(s) } },
      priorities: Project.priorities.keys.map { |p| { value: p, label: format_priority_for_display(p) } }
    }
  end

  # --------------------------------------------------------------------------
  # Strong Parameters
  # --------------------------------------------------------------------------

  def project_params
    params.require(:project).permit(
      :title,
      :description,
      :location,
      :budget,
      :start_date,
      :finishing_date,
      :priority,
      :status,
      :project_manager_id,
      :supervisor_id,
      :site_manager_id,
      :user_id,
      :lead_person,
      :responsible,
      :actual_start_date,
      :estimated_completion_date,
      :progress_percentage,
      :progress_notes
    )
  end

  # --------------------------------------------------------------------------
  # Progress Calculations
  # --------------------------------------------------------------------------

  def calculate_timeline_progress(project)
    return 0 unless project.finishing_date && project.start_date

    total_duration = (project.finishing_date.to_date - project.start_date.to_date).to_f
    return 0 if total_duration <= 0

    elapsed_duration = (Date.current - project.start_date.to_date).to_f
    progress = (elapsed_duration / total_duration) * 100
    progress.clamp(0, 100).round(2)
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

  def calculate_schedule_trend(trend_data)
    return 'stable' if trend_data.size < 2

    first_variance = trend_data.first[:variance] || 0
    last_variance = trend_data.last[:variance] || 0
    trend = last_variance - first_variance

    if trend > 5
      'catching_up'
    elsif trend < -5
      'falling_behind'
    else
      'stable'
    end
  end

  def calculate_progress_velocity(updates)
    return 0 if updates.count < 2

    first_update = updates.first
    last_update = updates.last
    
    progress_change = last_update.new_progress - first_update.new_progress
    days_elapsed = (last_update.created_at.to_date - first_update.created_at.to_date).to_f
    
    return 0 if days_elapsed <= 0

    # Progress per week
    ((progress_change / days_elapsed) * 7).round(2)
  end

  def calculate_projected_completion(project, velocity)
    return nil if velocity <= 0
    
    remaining_progress = 100 - project.progress_percentage.to_f
    days_needed = (remaining_progress / velocity) * 7
    
    (Date.current + days_needed.days).strftime('%Y-%m-%d')
  rescue
    nil
  end

  # --------------------------------------------------------------------------
  # Formatting Helpers
  # --------------------------------------------------------------------------

  def format_project_for_list(project)
    {
      id: project.id,
      title: project.title,
      name: project.title,
      description: project.description,
      location: project.location,
      budget: project.budget&.to_f || 0,
      start_date: project.start_date&.strftime('%Y-%m-%d'),
      finishing_date: project.finishing_date&.strftime('%Y-%m-%d'),
      status: project.status,
      priority: project.priority,
      progress_percentage: project.progress_percentage.to_f,
      progress: project.progress_percentage.to_f,
      project_manager_id: project.project_manager_id,
      supervisor_id: project.supervisor_id,
      site_manager_id: project.site_manager_id,
      project_manager: project.project_manager&.name,
      supervisor: project.supervisor&.name,
      site_manager: project.site_manager&.name,
      created_by: project.project_manager&.name,
      lead_person: project.lead_person,
      responsible: project.responsible,
      days_remaining: project.days_remaining,
      created_at: project.created_at,
      updated_at: project.updated_at
    }
  end

  def format_project_for_active(project)
    timeline_progress = calculate_timeline_progress(project)
    schedule_status = determine_schedule_status(project.progress_percentage.to_f, timeline_progress)

    {
      id: project.id,
      name: project.title,
      client: project.responsible || project.lead_person || "Client Name",
      status: format_status_for_display(project.status),
      priority: format_priority_for_display(project.priority),
      progress: project.progress_percentage.to_f,
      timeline_progress: timeline_progress,
      schedule_status: schedule_status,
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
      isStarred: false,
      description: project.description || "No description available",
      team: build_team_array(project),
      milestones: build_milestones_array(project),
      documents: [],
      recentUpdates: build_recent_updates(project)
    }
  end

  def format_project_for_completed(project)
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

  def format_project_detail(project)
    timeline_progress = calculate_timeline_progress(project)
    schedule_status = determine_schedule_status(project.progress_percentage.to_f, timeline_progress)

    {
      id: project.id,
      title: project.title,
      description: project.description,
      location: project.location,
      budget: project.budget&.to_f || 0,
      spent: calculate_spent_amount(project),
      start_date: project.start_date&.strftime('%Y-%m-%d'),
      finishing_date: project.finishing_date&.strftime('%Y-%m-%d'),
      status: project.status,
      status_display: format_status_for_display(project.status),
      priority: project.priority,
      priority_display: format_priority_for_display(project.priority),
      progress_percentage: project.progress_percentage.to_f,
      timeline_progress: timeline_progress,
      schedule_status: schedule_status,
      days_remaining: project.days_remaining,
      project_manager_id: project.project_manager_id,
      supervisor_id: project.supervisor_id,
      site_manager_id: project.site_manager_id,
      project_manager: project.project_manager&.name,
      supervisor: project.supervisor&.name,
      site_manager: project.site_manager&.name,
      lead_person: project.lead_person,
      responsible: project.responsible,
      team: build_team_array(project),
      milestones: build_milestones_array(project),
      recent_updates: build_recent_updates(project),
      created_at: project.created_at,
      updated_at: project.updated_at
    }
  end

  def format_status_for_display(status)
    {
      'in_progress' => 'In Progress',
      'planning' => 'Planning',
      'at_risk' => 'At Risk',
      'on_hold' => 'On Hold',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'review' => 'In Review'
    }[status.to_s] || status.to_s.humanize
  end

  def format_priority_for_display(priority)
    case priority.to_s
    when '0', 'low' then 'Low'
    when '1', 'medium' then 'Medium'
    when '2', 'high' then 'High'
    when '3', 'critical' then 'Critical'
    else priority.to_s.humanize
    end
  end

  # --------------------------------------------------------------------------
  # Project Data Helpers
  # --------------------------------------------------------------------------

  def calculate_spent_amount(project)
    budget = project.budget&.to_f || 0
    (budget * project.progress_percentage.to_f / 100).round(2)
  end

  def get_next_milestone_name(project)
    next_event = project.events.where('date > ?', Date.current).order(:date).first
    return next_event.description if next_event

    case project.status
    when 'planning' then 'Start Construction'
    when 'in_progress' then 'Next Phase Completion'
    when 'review' then 'Final Approval'
    else 'Project Completion'
    end
  end

  def get_next_milestone_date(project)
    next_event = project.events.where('date > ?', Date.current).order(:date).first
    return next_event.date&.strftime('%Y-%m-%d') if next_event

    project.finishing_date&.strftime('%Y-%m-%d')
  end

  def get_recent_activity(project)
    recent_update = project.progress_updates.order(created_at: :desc).first
    return recent_update.notes if recent_update&.notes.present?

    project.progress_notes.presence || "Project #{project.progress_percentage.to_i}% complete"
  end

  def calculate_risk_count(project)
    risk_count = 0
    risk_count += 1 if project.respond_to?(:behind_schedule?) && project.behind_schedule?
    risk_count += 1 if project.respond_to?(:overdue?) && project.overdue?
    risk_count += 1 if project.status == 'at_risk'
    risk_count += 1 if project.days_remaining&.negative?
    risk_count
  end

  def build_team_array(project)
    team = []

    if project.project_manager
      team << {
        id: project.project_manager.id,
        name: project.project_manager.name || 'Project Manager',
        role: 'Project Manager',
        avatar: get_avatar_initials(project.project_manager.name),
        email: project.project_manager.email
      }
    end

    if project.supervisor && project.supervisor.id != project.project_manager_id
      team << {
        id: project.supervisor.id,
        name: project.supervisor.name || 'Supervisor',
        role: 'Supervisor',
        avatar: get_avatar_initials(project.supervisor.name),
        email: project.supervisor.email
      }
    end

    if project.site_manager
      team << {
        id: project.site_manager.id,
        name: project.site_manager.name || 'Site Manager',
        role: 'Site Manager',
        avatar: get_avatar_initials(project.site_manager.name)
      }
    end

    team
  end

  def get_avatar_initials(name)
    return 'U' unless name.present?
    name.split.map(&:first).join.upcase[0..1]
  end

  def build_milestones_array(project)
    # Get actual milestones if they exist
    if project.respond_to?(:project_milestones) && project.project_milestones.any?
      return project.project_milestones.order(:order_position).map do |milestone|
        {
          id: milestone.id,
          name: milestone.name,
          status: milestone.status,
          planned_date: milestone.planned_date&.strftime('%Y-%m-%d'),
          actual_date: milestone.actual_date&.strftime('%Y-%m-%d'),
          progress_target: milestone.progress_percentage_target
        }
      end
    end

    # Fallback to generated milestones based on status
    [
      {
        name: 'Planning',
        status: milestone_status_for('planning', project.status),
        date: project.start_date&.strftime('%Y-%m-%d')
      },
      {
        name: 'Construction',
        status: milestone_status_for('in_progress', project.status),
        date: project.start_date ? (project.start_date + 30.days).strftime('%Y-%m-%d') : nil
      },
      {
        name: 'Review',
        status: milestone_status_for('review', project.status),
        date: project.finishing_date ? (project.finishing_date - 14.days).strftime('%Y-%m-%d') : nil
      },
      {
        name: 'Completion',
        status: milestone_status_for('completed', project.status),
        date: project.finishing_date&.strftime('%Y-%m-%d')
      }
    ]
  end

  def milestone_status_for(milestone_phase, current_status)
    order = { 'planning' => 0, 'in_progress' => 1, 'review' => 2, 'completed' => 3 }
    current = order[current_status] || 0
    target = order[milestone_phase] || 0

    if current > target
      'completed'
    elsif current == target
      'in_progress'
    else
      'pending'
    end
  end

  def build_recent_updates(project)
    updates = project.progress_updates.includes(:updated_by).order(created_at: :desc).limit(5)

    updates.map do |update|
      {
        id: update.id,
        date: update.created_at.strftime('%Y-%m-%d'),
        update: update.notes || "Progress updated to #{update.new_progress}%",
        author: update.updated_by&.name || 'System',
        progress: update.new_progress
      }
    end
  end

  # --------------------------------------------------------------------------
  # Activity Logging
  # --------------------------------------------------------------------------

  def log_activity(action, target: nil, target_type: nil, target_id: nil, metadata: {})
    Activity.create!(
      actor: current_user,
      action: action,
      target: target,
      target_type: target_type || target&.class&.name,
      target_id: target_id || target&.id,
      metadata: metadata
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log activity: #{e.message}"
  end
end