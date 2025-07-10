# class ProjectManagersController < ApplicationController
#     before_action :authenticate_user!
#     # before_action :ensure_project_manager
    
#     # Dashboard overview for project managers
#     def dashboard
#       @dashboard_data = {
#         projects: my_projects_data,
#         events: upcoming_events_data,
#         tenders: my_tenders_data,
#         statistics: dashboard_statistics,
#         recent_tasks: recent_tasks_data
#       }
      
#       render json: @dashboard_data
#     end
  
#     # Get all projects managed by current user
#     def my_projects
#       @projects = current_user.managed_projects
#                              .includes(:events, :tenders)
#                              .order(:finishing_date)
      
#       render json: @projects.map { |project| format_project_data(project) }
#     end
  
#     # Get upcoming events for project manager's projects
#     def upcoming_events
#       @events = Event.joins(:project)
#                     .where(projects: { project_manager_id: current_user.id })
#                     .where('date >= ?', Date.current)
#                     .order(:date)
#                     .limit(10)
      
#       render json: @events.map { |event| format_event_data(event) }
#     end
  
#     # Get tenders assigned to project manager
#     def my_tenders
#       @tenders = Tender.where(project_manager_id: current_user.id)
#                       .order(:deadline)
      
#       render json: @tenders.map { |tender| format_tender_data(tender) }
#     end
  
#     # Get project manager statistics
#     def statistics
#       render json: dashboard_statistics
#     end
  
#     # Get team members across all projects
#     def team_members
#       # Assuming you have a way to get team members per project
#       # This might need adjustment based on your actual team member model
#       @team_stats = {
#         total_members: calculate_total_team_members,
#         active_members: calculate_active_team_members,
#         projects_distribution: projects_team_distribution
#       }
      
#       render json: @team_stats
#     end
  
#     # Get project progress overview
#     def projects_progress
#       @projects = current_user.managed_projects
      
#       progress_data = @projects.map do |project|
#         {
#           id: project.id,
#           title: project.title,
#           progress: calculate_project_progress(project),
#           status: project.status,
#           deadline: project.finishing_date,
#           team_size: calculate_team_size(project),
#           budget_used: calculate_budget_usage(project)
#         }
#       end
      
#       render json: progress_data
#     end
  
#     private
  
#     def ensure_project_manager
#       # Add logic to ensure user is a project manager
#       # This depends on how you're handling roles
#       unless current_user.project_manager? || current_user.admin?
#         render json: { error: 'Access denied. Project Manager role required.' }, 
#                status: :forbidden
#       end
#     end
  
#     def my_projects_data
#       projects = current_user.managed_projects.includes(:events, :tenders)
      
#       projects.map { |project| format_project_data(project) }
#     end
  
#     def format_project_data(project)
#       {
#         id: project.id,
#         title: project.title,
#         status: project.status,
#         location: project.location,
#         finishing_date: project.finishing_date,
#         lead_person: project.lead_person,
#         responsible: project.responsible,
#         progress: calculate_project_progress(project),
#         priority: determine_project_priority(project),
#         team_size: calculate_team_size(project),
#         budget_used: calculate_budget_usage(project),
#         events_count: project.events.count,
#         upcoming_deadline: days_until_deadline(project.finishing_date),
#         created_at: project.created_at,
#         updated_at: project.updated_at
#       }
#     end
  
#     def upcoming_events_data
#       Event.joins(:project)
#            .where(projects: { project_manager_id: current_user.id })
#            .where('date >= ?', Date.current)
#            .order(:date)
#            .limit(10)
#            .map { |event| format_event_data(event) }
#     end
  
#     def format_event_data(event)
#       {
#         id: event.id,
#         description: event.description,
#         date: event.date,
#         responsible: event.responsible,
#         project_id: event.project_id,
#         project_title: event.project&.title,
#         type: determine_event_type(event.description),
#         days_until: days_until_date(event.date)
#       }
#     end
  
#     def my_tenders_data
#       Tender.where(project_manager_id: current_user.id)
#             .order(:deadline)
#             .map { |tender| format_tender_data(tender) }
#     end
  
#     def format_tender_data(tender)
#       {
#         id: tender.id,
#         title: tender.title,
#         description: tender.description,
#         deadline: tender.deadline,
#         responsible: tender.responsible,
#         project_id: tender.project_id,
#         project_title: tender.project&.title,
#         status: determine_tender_status(tender),
#         days_until_deadline: days_until_deadline(tender.deadline),
#         created_at: tender.created_at
#       }
#     end
  
#     def dashboard_statistics
#       projects = current_user.managed_projects
      
#       {
#         total_projects: projects.count,
#         active_projects: projects.where.not(status: 'completed').count,
#         completed_projects: projects.where(status: 'completed').count,
#         projects_in_planning: projects.where(status: 'planning').count,
#         projects_in_progress: projects.where(status: 'in_progress').count,
#         projects_in_review: projects.where(status: 'review').count,
#         total_team_members: calculate_total_team_members,
#         active_tenders: Tender.where(project_manager_id: current_user.id).count,
#         upcoming_events: upcoming_events_count,
#         overdue_projects: overdue_projects_count,
#         completion_rate: calculate_completion_rate,
#         this_month_projects: projects.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
#       }
#     end
  
#     def recent_tasks_data
#       # This is a mock implementation - adjust based on your task management system
#       projects = current_user.managed_projects.limit(5)
      
#       tasks = []
#       projects.each do |project|
#         # Add some mock tasks - replace with your actual task logic
#         tasks << {
#           id: "task_#{project.id}_1",
#           task: "Review architectural plans",
#           project: project.title,
#           due: determine_task_due_date(project),
#           status: determine_task_status(project),
#           priority: determine_project_priority(project)
#         }
        
#         if project.events.exists?
#           tasks << {
#             id: "task_#{project.id}_2", 
#             task: "Prepare for #{project.events.upcoming.first&.description}",
#             project: project.title,
#             due: project.events.upcoming.first&.date || "TBD",
#             status: "pending",
#             priority: determine_project_priority(project)
#           }
#         end
#       end
      
#       tasks.sort_by { |task| task[:due] == "TBD" ? Date.current + 1000 : Date.parse(task[:due].to_s) }
#            .first(10)
#     end
  
#     # Helper methods for calculations
#     def calculate_project_progress(project)
#       # Basic progress calculation - customize based on your business logic
#       case project.status
#       when 'planning' then rand(10..30)
#       when 'in_progress' then rand(30..80)
#       when 'review' then rand(80..95)
#       when 'completed' then 100
#       else 0
#       end
#     end
  
#     def determine_project_priority(project)
#       return 'high' if project.finishing_date && project.finishing_date <= 1.month.from_now
#       return 'medium' if project.finishing_date && project.finishing_date <= 3.months.from_now
#       'low'
#     end
  
#     def calculate_team_size(project)
#       # Mock team size - replace with actual team member calculation
#       case project.status
#       when 'planning' then rand(3..6)
#       when 'in_progress' then rand(6..15)
#       when 'review' then rand(3..8)
#       else rand(1..12)
#       end
#     end
  
#     def calculate_budget_usage(project)
#       # Mock budget usage - replace with actual budget calculation
#       case project.status
#       when 'planning' then rand(5..25)
#       when 'in_progress' then rand(25..75)
#       when 'review' then rand(75..95)
#       when 'completed' then rand(85..100)
#       else 0
#       end
#     end
  
#     def calculate_total_team_members
#       # Sum up team members across all projects
#       current_user.managed_projects.sum { |project| calculate_team_size(project) }
#     end
  
#     def calculate_active_team_members
#       # Calculate active team members
#       current_user.managed_projects.where.not(status: 'completed').sum { |project| calculate_team_size(project) }
#     end
  
#     def projects_team_distribution
#       current_user.managed_projects.map do |project|
#         {
#           project_name: project.title,
#           team_size: calculate_team_size(project),
#           status: project.status
#         }
#       end
#     end
  
#     def upcoming_events_count
#       Event.joins(:project)
#            .where(projects: { project_manager_id: current_user.id })
#            .where('date >= ? AND date <= ?', Date.current, 1.week.from_now)
#            .count
#     end
  
#     def overdue_projects_count
#       current_user.managed_projects
#                   .where('finishing_date < ? AND status != ?', Date.current, 'completed')
#                   .count
#     end
  
#     def calculate_completion_rate
#       total = current_user.managed_projects.count
#       return 0 if total.zero?
      
#       completed = current_user.managed_projects.where(status: 'completed').count
#       (completed.to_f / total * 100).round(1)
#     end
  
#     def days_until_deadline(date)
#       return nil unless date
#       (date.to_date - Date.current).to_i
#     end
  
#     def days_until_date(date)
#       return nil unless date
#       (date.to_date - Date.current).to_i
#     end
  
#     def determine_event_type(description)
#       case description.downcase
#       when /meeting|standup|kickoff/ then 'meeting'
#       when /review|presentation|demo/ then 'review'
#       when /inspection|visit|site/ then 'inspection'
#       when /deadline|delivery|submission/ then 'deadline'
#       else 'meeting'
#       end
#     end
  
#     def determine_tender_status(tender)
#       return 'overdue' if tender.deadline < Date.current
#       return 'urgent' if tender.deadline <= 3.days.from_now
#       return 'pending' if tender.deadline <= 1.week.from_now
#       'active'
#     end
  
#     def determine_task_due_date(project)
#       # Mock task due dates based on project
#       case project.status
#       when 'in_progress' then ['Today', 'Tomorrow', Date.current + 2.days].sample
#       when 'review' then ['Today', Date.current + 1.day].sample
#       else Date.current + rand(1..7).days
#       end
#     end
  
#     def determine_task_status(project)
#       case project.status
#       when 'in_progress' then ['pending', 'in_progress'].sample
#       when 'review' then 'pending'
#       when 'completed' then 'completed'
#       else 'pending'
#       end
#     end
#   end

# class ProjectManagersController < ApplicationController
#   before_action :authenticate_user!

#   def dashboard
#     @dashboard_data = {
#       projects: my_projects_data,
#       events: upcoming_events_data,
#       tenders: my_tenders_data,
#       statistics: dashboard_statistics,
#       recent_tasks: recent_tasks_data
#     }

#     render json: @dashboard_data
#   end

#   def my_projects
#     @projects = current_user.managed_projects
#                            .includes(:events, :tenders)
#                            .order(:finishing_date)

#     render json: @projects.map { |project| format_project_data(project) }
#   end

#   def upcoming_events
#     @events = Event.joins(:project)
#                   .where(projects: { project_manager_id: current_user.id })
#                   .where('date >= ?', Date.current)
#                   .order(:date)
#                   .limit(10)

#     render json: @events.map { |event| format_event_data(event) }
#   end

#   def my_tenders
#     @tenders = Tender.where(project_manager_id: current_user.id)
#                     .order(:deadline)

#     render json: @tenders.map { |tender| format_tender_data(tender) }
#   end

#   def statistics
#     render json: dashboard_statistics
#   end

#   def team_members
#     @team_stats = {
#       total_members: calculate_total_team_members,
#       active_members: calculate_active_team_members,
#       projects_distribution: projects_team_distribution
#     }

#     render json: @team_stats
#   end

#   def projects_progress
#     @projects = current_user.managed_projects

#     progress_data = @projects.map do |project|
#       {
#         id: project.id,
#         title: project.title,
#         progress: project.progress_percentage,
#         status: project.status,
#         deadline: project.finishing_date,
#         team_size: calculate_team_size(project),
#         budget_used: calculate_budget_usage(project)
#       }
#     end

#     render json: progress_data
#   end

#   private

#   def ensure_project_manager
#     unless current_user.project_manager? || current_user.admin?
#       render json: { error: 'Access denied. Project Manager role required.' }, status: :forbidden
#     end
#   end

#   def my_projects_data
#     projects = current_user.managed_projects.includes(:events, :tenders)
#     projects.map { |project| format_project_data(project) }
#   end

#   def format_project_data(project)
#     {
#       id: project.id,
#       title: project.title,
#       status: project.status,
#       location: project.location,
#       finishing_date: project.finishing_date,
#       lead_person: project.lead_person,
#       responsible: project.responsible,
#       progress: project.progress_percentage,
#       priority: determine_project_priority(project),
#       team_size: calculate_team_size(project),
#       budget_used: calculate_budget_usage(project),
#       events_count: project.events.count,
#       upcoming_deadline: days_until_deadline(project.finishing_date),
#       created_at: project.created_at,
#       updated_at: project.updated_at
#     }
#   end

#   def upcoming_events_data
#     Event.joins(:project)
#          .where(projects: { project_manager_id: current_user.id })
#          .where('date >= ?', Date.current)
#          .order(:date)
#          .limit(10)
#          .map { |event| format_event_data(event) }
#   end

#   def format_event_data(event)
#     {
#       id: event.id,
#       description: event.description,
#       date: event.date,
#       responsible: event.responsible,
#       project_id: event.project_id,
#       project_title: event.project&.title,
#       type: determine_event_type(event.description),
#       days_until: days_until_date(event.date)
#     }
#   end

#   def my_tenders_data
#     Tender.where(project_manager_id: current_user.id)
#           .order(:deadline)
#           .map { |tender| format_tender_data(tender) }
#   end

#   def format_tender_data(tender)
#     {
#       id: tender.id,
#       title: tender.title,
#       description: tender.description,
#       deadline: tender.deadline,
#       responsible: tender.responsible,
#       project_id: tender.project_id,
#       project_title: tender.project&.title,
#       status: determine_tender_status(tender),
#       days_until_deadline: days_until_deadline(tender.deadline),
#       created_at: tender.created_at
#     }
#   end

#   def dashboard_statistics
#     projects = current_user.managed_projects

#     {
#       total_projects: projects.count,
#       active_projects: projects.where.not(status: Project.statuses[:completed]).count,
#       completed_projects: projects.where(status: Project.statuses[:completed]).count,
#       projects_in_planning: projects.where(status: Project.statuses[:planning]).count,
#       projects_in_progress: projects.where(status: Project.statuses[:in_progress]).count,
#       projects_in_review: projects.where(status: Project.statuses[:review]).count,
#       total_team_members: calculate_total_team_members,
#       active_tenders: Tender.where(project_manager_id: current_user.id).count,
#       upcoming_events: upcoming_events_count,
#       overdue_projects: overdue_projects_count,
#       completion_rate: calculate_completion_rate,
#       this_month_projects: projects.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
#     }
#   end

#   def recent_tasks_data
#     projects = current_user.managed_projects.limit(5)

#     tasks = []
#     projects.each do |project|
#       tasks << {
#         id: "task_#{project.id}_1",
#         task: "Review architectural plans",
#         project: project.title,
#         due: determine_task_due_date(project),
#         status: determine_task_status(project),
#         priority: determine_project_priority(project)
#       }

#       if project.events.exists?
#         tasks << {
#           id: "task_#{project.id}_2",
#           task: "Prepare for #{project.events.upcoming.first&.description}",
#           project: project.title,
#           due: project.events.upcoming.first&.date || "TBD",
#           status: "pending",
#           priority: determine_project_priority(project)
#         }
#       end
#     end

#     tasks.sort_by { |task| task[:due] == "TBD" ? Date.current + 1000 : Date.parse(task[:due].to_s) }.first(10)
#   end

#   def determine_project_priority(project)
#     return 'high' if project.finishing_date && project.finishing_date <= 1.month.from_now
#     return 'medium' if project.finishing_date && project.finishing_date <= 3.months.from_now
#     'low'
#   end

#   def calculate_team_size(project)
#     case project.status
#     when 'planning' then rand(3..6)
#     when 'in_progress' then rand(6..15)
#     when 'review' then rand(3..8)
#     else rand(1..12)
#     end
#   end

#   def calculate_budget_usage(project)
#     case project.status
#     when 'planning' then rand(5..25)
#     when 'in_progress' then rand(25..75)
#     when 'review' then rand(75..95)
#     when 'completed' then rand(85..100)
#     else 0
#     end
#   end

#   def calculate_total_team_members
#     current_user.managed_projects.sum { |project| calculate_team_size(project) }
#   end

#   def calculate_active_team_members
#     current_user.managed_projects.where.not(status: Project.statuses[:completed]).sum { |project| calculate_team_size(project) }
#   end

#   def projects_team_distribution
#     current_user.managed_projects.map do |project|
#       {
#         project_name: project.title,
#         team_size: calculate_team_size(project),
#         status: project.status
#       }
#     end
#   end

#   def upcoming_events_count
#     Event.joins(:project)
#          .where(projects: { project_manager_id: current_user.id })
#          .where('date >= ? AND date <= ?', Date.current, 1.week.from_now)
#          .count
#   end

#   def overdue_projects_count
#     current_user.managed_projects
#                 .where('finishing_date < ? AND status != ?', Date.current, Project.statuses[:completed])
#                 .count
#   end

#   def calculate_completion_rate
#     total = current_user.managed_projects.count
#     return 0 if total.zero?

#     completed = current_user.managed_projects.where(status: Project.statuses[:completed]).count
#     (completed.to_f / total * 100).round(1)
#   end

#   def days_until_deadline(date)
#     return nil unless date
#     (date.to_date - Date.current).to_i
#   end

#   def days_until_date(date)
#     return nil unless date
#     (date.to_date - Date.current).to_i
#   end

#   def determine_event_type(description)
#     case description.downcase
#     when /meeting|standup|kickoff/ then 'meeting'
#     when /review|presentation|demo/ then 'review'
#     when /inspection|visit|site/ then 'inspection'
#     when /deadline|delivery|submission/ then 'deadline'
#     else 'meeting'
#     end
#   end

#   def determine_tender_status(tender)
#     return 'overdue' if tender.deadline < Date.current
#     return 'urgent' if tender.deadline <= 3.days.from_now
#     return 'pending' if tender.deadline <= 1.week.from_now
#     'active'
#   end

#   def determine_task_due_date(project)
#     case project.status
#     when 'in_progress' then ['Today', 'Tomorrow', Date.current + 2.days].sample
#     when 'review' then ['Today', Date.current + 1.day].sample
#     else Date.current + rand(1..7).days
#     end
#   end

#   def determine_task_status(project)
#     case project.status
#     when 'in_progress' then ['pending', 'in_progress'].sample
#     when 'review' then 'pending'
#     when 'completed' then 'completed'
#     else 'pending'
#     end
#   end
# end

class ProjectManagersController < ApplicationController
  before_action :authenticate_user!

  
  def dashboard
    @dashboard_data = {
      projects: my_projects_data,
      events: upcoming_events_data,
      tenders: my_tenders_data,
      statistics: dashboard_statistics,
      recent_tasks: recent_tasks_data
    }
    render json: @dashboard_data
  end

  def my_projects
    @projects = current_user.managed_projects
                           .includes(:events, :tenders)
                           .order(:finishing_date)
    render json: @projects.map { |project| format_project_data(project) }
  end

  def update_progress
    @project = current_user.managed_projects.find_by(id: params[:id])
    unless @project
      return render json: { error: "Project not found or not authorized" }, status: :not_found
    end

    old_progress = @project.progress_percentage
    new_progress = progress_params[:progress_percentage].to_f
    timeline_progress = calculate_timeline_progress(@project)
    variance = new_progress - timeline_progress
    schedule_status = determine_schedule_status(new_progress, timeline_progress)
    warning = variance.abs > 30 ? "Warning: Progress is significantly off expected timeline progress." : nil

    if @project.update(progress_percentage: new_progress, last_progress_update: Time.current, progress_notes: progress_params[:note])
      ProgressUpdate.create!(
        project: @project,
        old_progress: old_progress,
        new_progress: new_progress,
        notes: progress_params[:note],
        updated_by_id: current_user.id,
        update_type: "manual",
        timeline_progress_at_update: timeline_progress,
        variance_at_update: variance,
        project_status_at_update: @project.status
      )

      render json: { 
        message: "Progress updated successfully", 
        project: {
          id: @project.id,
          progress_percentage: new_progress,
          timeline_progress: timeline_progress,
          variance: variance,
          schedule_status: schedule_status
        },
        warning: warning
      }, status: :ok
    else
      render json: { error: @project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def progress_history
    @project = current_user.managed_projects.find_by(id: params[:id])
    unless @project
      return render json: { error: "Project not found or not authorized" }, status: :not_found
    end

    updates = @project.progress_updates
                      .includes(:updated_by)
                      .order(created_at: :desc)
                      .map do |update|
      {
        old_progress: update.old_progress,
        new_progress: update.new_progress,
        note: update.notes,
        updated_by: update.updated_by&.name,
        timestamp: update.created_at
      }
    end
    render json: { project_id: @project.id, history: updates }
  end

  def upcoming_events
    @events = Event.joins(:project)
                  .where(projects: { project_manager_id: current_user.id })
                  .where('date >= ?', Date.current)
                  .order(:date)
                  .limit(10)
    render json: @events.map { |event| format_event_data(event) }
  end

  def my_tenders
    @tenders = Tender.where(project_manager_id: current_user.id)
                    .order(:deadline)
    render json: @tenders.map { |tender| format_tender_data(tender) }
  end

  def statistics
    render json: dashboard_statistics
  end

  def team_members
    @team_stats = {
      total_members: calculate_total_team_members,
      active_members: calculate_active_team_members,
      projects_distribution: projects_team_distribution
    }
    render json: @team_stats
  end

  def projects_progress
    @projects = current_user.managed_projects
    progress_data = @projects.map do |project|
      timeline_progress = calculate_timeline_progress(project)
      variance = project.progress_percentage.to_f - timeline_progress
      schedule_status = determine_schedule_status(project.progress_percentage.to_f, timeline_progress)
      {
        id: project.id,
        title: project.title,
        progress: project.progress_percentage,
        timeline_progress: timeline_progress,
        variance: variance,
        schedule_status: schedule_status,
        status: project.status,
        deadline: project.finishing_date,
        team_size: calculate_team_size(project),
        budget_used: calculate_budget_usage(project)
      }
    end
    render json: progress_data
  end

  private

  def progress_params
    params.require(:project).permit(:progress_percentage, :note)
  end

  def ensure_project_manager
    unless current_user.project_manager? || current_user.admin?
      render json: { error: 'Access denied. Project Manager role required.' }, status: :forbidden
    end
  end

  # FIXED: Bypass association caching to get fresh data
  def my_projects_data
    project_ids = current_user.managed_projects.pluck(:id)
    projects = Project.where(id: project_ids).includes(:events, :tenders)
    projects.map { |project| format_project_data(project) }
  end

  def format_project_data(project)
    {
      id: project.id,
      title: project.title,
      status: project.status,
      location: project.location,
      finishing_date: project.finishing_date,
      lead_person: project.lead_person,
      responsible: project.responsible,
      progress: project.progress_percentage,
      priority: determine_project_priority(project),
      team_size: calculate_team_size(project),
      budget_used: calculate_budget_usage(project),
      events_count: project.events.count,
      upcoming_deadline: days_until_deadline(project.finishing_date),
      created_at: project.created_at,
      updated_at: project.updated_at
    }
  end

  def upcoming_events_data
    Event.joins(:project)
         .where(projects: { project_manager_id: current_user.id })
         .where('date >= ?', Date.current)
         .order(:date)
         .limit(10)
         .map { |event| format_event_data(event) }
  end

  def format_event_data(event)
    {
      id: event.id,
      description: event.description,
      date: event.date,
      responsible: event.responsible,
      project_id: event.project_id,
      project_title: event.project&.title,
      type: determine_event_type(event.description),
      days_until: days_until_date(event.date)
    }
  end



  def my_tenders
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
  
  private
  
  def tender_json(tender)
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
      status_color: tender.status_color
    }
  end
  
  def my_tenders_data
    Tender.where(project_manager_id: current_user.id)
          .order(:deadline)
          .map { |tender| format_tender_data(tender) }
  end

  def format_tender_data(tender)
    {
      id: tender.id,
      title: tender.title,
      description: tender.description,
      deadline: tender.deadline,
      responsible: tender.responsible,
      project_id: tender.project_id,
      project_title: tender.project&.title,
      status: determine_tender_status(tender),
      days_until_deadline: days_until_deadline(tender.deadline),
      created_at: tender.created_at
    }
  end

  def dashboard_statistics
    projects = current_user.managed_projects
    {
      total_projects: projects.count,
      active_projects: projects.where.not(status: Project.statuses[:completed]).count,
      completed_projects: projects.where(status: Project.statuses[:completed]).count,
      projects_in_planning: projects.where(status: Project.statuses[:planning]).count,
      projects_in_progress: projects.where(status: Project.statuses[:in_progress]).count,
      projects_in_review: projects.where(status: Project.statuses[:review]).count,
      total_team_members: calculate_total_team_members,
      active_tenders: Tender.where(project_manager_id: current_user.id).count,
      upcoming_events: upcoming_events_count,
      overdue_projects: overdue_projects_count,
      completion_rate: calculate_completion_rate,
      this_month_projects: projects.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
    }
  end

  def recent_tasks_data
    projects = current_user.managed_projects.limit(5)
    tasks = []
    projects.each do |project|
      tasks << {
        id: "task_#{project.id}_1",
        task: "Review architectural plans",
        project: project.title,
        due: determine_task_due_date(project),
        status: determine_task_status(project),
        priority: determine_project_priority(project)
      }
      if project.events.exists?
        tasks << {
          id: "task_#{project.id}_2",
          task: "Prepare for #{project.events.upcoming.first&.description}",
          project: project.title,
          due: project.events.upcoming.first&.date || "TBD",
          status: "pending",
          priority: determine_project_priority(project)
        }
      end
    end
    tasks.sort_by { |task| task[:due] == "TBD" ? Date.current + 1000 : Date.parse(task[:due].to_s) }.first(10)
  end

  def determine_project_priority(project)
    return 'high' if project.finishing_date && project.finishing_date <= 1.month.from_now
    return 'medium' if project.finishing_date && project.finishing_date <= 3.months.from_now
    'low'
  end

  def calculate_team_size(project)
    case project.status
    when 'planning' then rand(3..6)
    when 'in_progress' then rand(6..15)
    when 'review' then rand(3..8)
    else rand(1..12)
    end
  end

  def calculate_budget_usage(project)
    case project.status
    when 'planning' then rand(5..25)
    when 'in_progress' then rand(25..75)
    when 'review' then rand(75..95)
    when 'completed' then rand(85..100)
    else 0
    end
  end

  def calculate_total_team_members
    current_user.managed_projects.sum { |project| calculate_team_size(project) }
  end

  def calculate_active_team_members
    current_user.managed_projects.where.not(status: Project.statuses[:completed]).sum { |project| calculate_team_size(project) }
  end

  def projects_team_distribution
    current_user.managed_projects.map do |project|
      {
        project_name: project.title,
        team_size: calculate_team_size(project),
        status: project.status
      }
    end
  end

  def upcoming_events_count
    Event.joins(:project)
         .where(projects: { project_manager_id: current_user.id })
         .where('date >= ? AND date <= ?', Date.current, 1.week.from_now)
         .count
  end

  def overdue_projects_count
    current_user.managed_projects
                .where('finishing_date < ? AND status != ?', Date.current, Project.statuses[:completed])
                .count
  end

  def calculate_completion_rate
    total = current_user.managed_projects.count
    return 0 if total.zero?
    completed = current_user.managed_projects.where(status: Project.statuses[:completed]).count
    (completed.to_f / total * 100).round(1)
  end

  def days_until_deadline(date)
    return nil unless date
    (date.to_date - Date.current).to_i
  end

  def days_until_date(date)
    return nil unless date
    (date.to_date - Date.current).to_i
  end

  def determine_event_type(description)
    case description.downcase
    when /meeting|standup|kickoff/ then 'meeting'
    when /review|presentation|demo/ then 'review'
    when /inspection|visit|site/ then 'inspection'
    when /deadline|delivery|submission/ then 'deadline'
    else 'meeting'
    end
  end

  def determine_tender_status(tender)
    return 'overdue' if tender.deadline < Date.current
    return 'urgent' if tender.deadline <= 3.days.from_now
    return 'pending' if tender.deadline <= 1.week.from_now
    'active'
  end

  def determine_task_due_date(project)
    case project.status
    when 'in_progress' then ['Today', 'Tomorrow', Date.current + 2.days].sample
    when 'review' then ['Today', Date.current + 1.day].sample
    else Date.current + rand(1..7).days
    end
  end

  def determine_task_status(project)
    case project.status
    when 'in_progress' then ['pending', 'in_progress'].sample
    when 'review' then 'pending'
    when 'completed' then 'completed'
    else 'pending'
    end
  end

  # Helper methods for timeline progress and schedule status
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