class CalendarController < ApplicationController
  before_action :authenticate_user!

  # ============================================================================
  # PUBLIC ENDPOINTS
  # ============================================================================

  # GET /calendar
  def index
    render json: { message: 'Calendar API endpoint' }
  end

  # GET /calendar/events
  def events
    start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    end_date   = params[:end_date]&.to_date   || Date.current.end_of_month

    render json: { events: fetch_all_events(start_date, end_date) }
  end

  # GET /calendar/month/:year/:month
  def month
    year  = params[:year].to_i
    month = params[:month].to_i
    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month

    render json: { events: fetch_all_events(start_date, end_date) }
  end

  # ============================================================================
  # PRIVATE METHODS
  # ============================================================================

  private

  # --------------------------------------------------------------------------
  # Aggregate Events
  # --------------------------------------------------------------------------
  def fetch_all_events(start_date, end_date)
    [].tap do |events|
      events.concat(get_project_events(start_date, end_date))
      events.concat(get_task_events(start_date, end_date))
      events.concat(get_tender_events(start_date, end_date))
      events.concat(get_direct_events(start_date, end_date))
    end.sort_by { |event| event[:date] }
  end

  # --------------------------------------------------------------------------
  # Current User Scopes
  # --------------------------------------------------------------------------
  def current_user_projects
    return Project.all if current_user.admin?

    Project.where(
      'project_manager_id = ? OR supervisor_id = ?', 
      current_user.id, current_user.id
    )
  end

  def current_user_tasks
    return Task.all if current_user.admin?

    Task.where(
      'project_manager_id = ? OR user_id = ?', 
      current_user.id, current_user.id
    )
  end

  def current_user_tenders
    return Tender.all if current_user.admin?

    Tender.where(project_manager_id: current_user.id)
  end

  # --------------------------------------------------------------------------
  # Event Helpers
  # --------------------------------------------------------------------------
  def calculate_priority(days_until)
    return "high"   if days_until <= 3
    return "medium" if days_until <= 7
    "low"
  end

  def event_status(entity, event_date)
    if entity.respond_to?(:completed?)
      entity.completed? ? "completed" : "scheduled"
    else
      event_date < Date.current ? "completed" : "scheduled"
    end
  end

  # --------------------------------------------------------------------------
  # Project Events
  # --------------------------------------------------------------------------
  def get_project_events(start_date, end_date)
    projects = current_user_projects.includes(:project_manager, :supervisor)
    events = []

    projects.each do |project|
      # Start
      if project.start_date&.between?(start_date, end_date)
        events << build_event(project, project.start_date, "Project Start", "project_start", "bg-green-500", "09:00")
      end

      # Deadline
      if project.finishing_date&.between?(start_date, end_date)
        days_until = (project.finishing_date - Date.current).to_i
        events << build_event(project, project.finishing_date, "Deadline", "deadline", "bg-red-500", "17:00", calculate_priority(days_until))
      end

      # Monthly Progress Review
      if project.start_date && project.finishing_date
        current_review_date = project.start_date.beginning_of_month.next_month
        while current_review_date <= project.finishing_date && current_review_date <= end_date
          if current_review_date.between?(start_date, end_date) && current_review_date <= Date.current.next_month
            events << build_event(project, current_review_date, "Progress Review", "review", "bg-purple-500", "14:00", "medium", attendees: [project.project_manager&.name, project.supervisor&.name, "Stakeholders"])
          end
          current_review_date = current_review_date.next_month
        end
      end
    end

    events
  end

  # --------------------------------------------------------------------------
  # Task Events
  # --------------------------------------------------------------------------
  def get_task_events(start_date, end_date)
    tasks = current_user_tasks.includes(:project_manager, :user, :project)
    tasks.flat_map do |task|
      events = []

      # Task due
      if task.due_date&.between?(start_date, end_date)
        days_until = (task.due_date - Date.current).to_i
        events << build_event(task, task.due_date, "Due", "deadline", "bg-orange-500", "17:00", calculate_priority(days_until), project: task.project)
      end

      # Task start
      if task.start_date&.between?(start_date, end_date)
        events << build_event(task, task.start_date, "Start", "task_start", "bg-blue-500", "09:00", task.priority || "medium", project: task.project, attendees: [task.project_manager&.name, task.user&.name])
      end

      events
    end
  end

  # --------------------------------------------------------------------------
  # Tender Events
  # --------------------------------------------------------------------------
  def get_tender_events(start_date, end_date)
    tenders = current_user_tenders.includes(:project_manager, :project)
    tenders.flat_map do |tender|
      next [] unless tender.deadline&.between?(start_date, end_date)
      days_until = (tender.deadline - Date.current).to_i
      build_event(tender, tender.deadline, "Tender Deadline", "deadline", "bg-yellow-500", "23:59", calculate_priority(days_until), project: tender.project, attendees: [tender.project_manager&.name, tender.lead_person, tender.responsible])
    end
  end

  # --------------------------------------------------------------------------
  # Direct Events
  # --------------------------------------------------------------------------
  def get_direct_events(start_date, end_date)
    Event.joins(:project)
         .where(date: start_date..end_date)
         .where(projects: { project_manager_id: current_user.id })
         .includes(:project)
         .map do |event|
      build_event(event, event.date, "Meeting", "meeting", "bg-indigo-500", "10:00", "medium", project: event.project, attendees: [event.responsible, event.project&.project_manager&.name])
    end
  end

  # --------------------------------------------------------------------------
  # Build Event Helper
  # --------------------------------------------------------------------------
  def build_event(entity, date, title_suffix, type, color, time = "09:00", priority = "medium", project: nil, attendees: nil)
    project ||= entity.respond_to?(:project) ? entity.project : nil
    {
      id: "#{type}_#{entity.id}#{date.is_a?(Date) ? "_#{date.strftime('%Y%m')}" : ''}",
      title: "#{entity.respond_to?(:title) ? entity.title : 'Event'} - #{title_suffix}",
      description: entity.respond_to?(:description) ? entity.description : "#{title_suffix} event",
      date: date.strftime('%Y-%m-%d'),
      time: time,
      type: type,
      category: entity.class.name.downcase,
      project: project&.title || "General",
      project_id: project&.id,
      location: project&.location || "TBD",
      attendees: attendees || default_attendees(entity, project),
      status: event_status(entity, date),
      priority: priority,
      color: color
    }
  end

  # Default attendees
  def default_attendees(entity, project)
    attendees = []
    attendees << project.project_manager&.name if project&.project_manager
    attendees << project.supervisor&.name if project&.supervisor
    attendees.compact
  end
end
