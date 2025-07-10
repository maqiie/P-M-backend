class CalendarController < ApplicationController
    before_action :authenticate_user!
  
    # GET /calendar
    def index
      render json: { message: 'Calendar API endpoint' }
    end
  
    # GET /calendar/events
    def events
      start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
      end_date = params[:end_date]&.to_date || Date.current.end_of_month
      
      all_events = []
      
      # Get events from projects
      all_events.concat(get_project_events(start_date, end_date))
      
      # Get events from tasks
      all_events.concat(get_task_events(start_date, end_date))
      
      # Get events from tenders
      all_events.concat(get_tender_events(start_date, end_date))
      
      # Get direct events
      all_events.concat(get_direct_events(start_date, end_date))
      
      # Sort by date
      all_events.sort_by! { |event| event[:date] }
      
      render json: { events: all_events }
    end
  
    # GET /calendar/month/:year/:month
    def month
      year = params[:year].to_i
      month = params[:month].to_i
      
      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_month
      
      all_events = []
      all_events.concat(get_project_events(start_date, end_date))
      all_events.concat(get_task_events(start_date, end_date))
      all_events.concat(get_tender_events(start_date, end_date))
      all_events.concat(get_direct_events(start_date, end_date))
      
      all_events.sort_by! { |event| event[:date] }
      
      render json: { events: all_events }
    end
  
    private
  
    def current_user_projects
      if current_user.admin?
        Project.all
      else
        Project.where(
          'project_manager_id = ? OR supervisor_id = ?', 
          current_user.id, current_user.id
        )
      end
    end
  
    def current_user_tasks
      if current_user.admin?
        Task.all
      else
        Task.where(
          'project_manager_id = ? OR user_id = ?', 
          current_user.id, current_user.id
        )
      end
    end
  
    def current_user_tenders
      if current_user.admin?
        Tender.all
      else
        Tender.where(project_manager_id: current_user.id)
      end
    end
  
    def get_project_events(start_date, end_date)
      projects = current_user_projects.includes(:project_manager, :supervisor)
      events = []
  
      projects.each do |project|
        # Project start date event
        if project.start_date && project.start_date.between?(start_date, end_date)
          events << {
            id: "project_start_#{project.id}",
            title: "#{project.title} - Project Start",
            description: "Project kickoff and initial setup",
            date: project.start_date.strftime('%Y-%m-%d'),
            time: "09:00",
            type: "project_start",
            category: "project",
            project: project.title,
            project_id: project.id,
            location: project.location || "Project Site",
            attendees: [project.project_manager&.name, project.supervisor&.name].compact,
            status: "scheduled",
            priority: project.priority || "medium",
            color: "bg-green-500"
          }
        end
  
        # Project deadline event
        if project.finishing_date && project.finishing_date.between?(start_date, end_date)
          days_until = (project.finishing_date - Date.current).to_i
          priority = days_until <= 7 ? "high" : (days_until <= 30 ? "medium" : "low")
          
          events << {
            id: "project_deadline_#{project.id}",
            title: "#{project.title} - Deadline",
            description: "Project completion deadline",
            date: project.finishing_date.strftime('%Y-%m-%d'),
            time: "17:00",
            type: "deadline",
            category: "project",
            project: project.title,
            project_id: project.id,
            location: project.location || "Project Site",
            attendees: [project.project_manager&.name, project.supervisor&.name].compact,
            status: project.completed? ? "completed" : "scheduled",
            priority: priority,
            color: "bg-red-500"
          }
        end
  
        # Progress review events (monthly)
        if project.start_date && project.finishing_date
          current_review_date = project.start_date.beginning_of_month.next_month
          while current_review_date <= project.finishing_date && current_review_date <= end_date
            if current_review_date.between?(start_date, end_date) && current_review_date <= Date.current.next_month
              events << {
                id: "project_review_#{project.id}_#{current_review_date.strftime('%Y%m')}",
                title: "#{project.title} - Progress Review",
                description: "Monthly progress review and status update",
                date: current_review_date.strftime('%Y-%m-%d'),
                time: "14:00",
                type: "review",
                category: "project",
                project: project.title,
                project_id: project.id,
                location: "Conference Room",
                attendees: [project.project_manager&.name, project.supervisor&.name, "Stakeholders"].compact,
                status: current_review_date < Date.current ? "completed" : "scheduled",
                priority: "medium",
                color: "bg-purple-500"
              }
            end
            current_review_date = current_review_date.next_month
          end
        end
      end
  
      events
    end
  
    def get_task_events(start_date, end_date)
      tasks = current_user_tasks.includes(:project_manager, :user, :project)
      events = []
  
      tasks.each do |task|
        # Task due date event
        if task.due_date && task.due_date.between?(start_date, end_date)
          days_until = (task.due_date - Date.current).to_i
          priority = days_until <= 1 ? "high" : (days_until <= 7 ? "medium" : "low")
          
          events << {
            id: "task_due_#{task.id}",
            title: "#{task.title} - Due",
            description: task.description || "Task deadline",
            date: task.due_date.strftime('%Y-%m-%d'),
            time: "17:00",
            type: "deadline",
            category: "task",
            project: task.project&.title || "General Tasks",
            project_id: task.project_id,
            location: task.project&.location || "Office",
            attendees: [task.project_manager&.name, task.user&.name].compact,
            status: task.completed? ? "completed" : "scheduled",
            priority: priority,
            color: "bg-orange-500"
          }
        end
  
        # Task start date event
        if task.start_date && task.start_date.between?(start_date, end_date)
          events << {
            id: "task_start_#{task.id}",
            title: "#{task.title} - Start",
            description: "Begin working on task",
            date: task.start_date.strftime('%Y-%m-%d'),
            time: "09:00",
            type: "task_start",
            category: "task",
            project: task.project&.title || "General Tasks",
            project_id: task.project_id,
            location: "Office",
            attendees: [task.project_manager&.name, task.user&.name].compact,
            status: task.status == 'pending' ? "scheduled" : "started",
            priority: task.priority || "medium",
            color: "bg-blue-500"
          }
        end
      end
  
      events
    end
  
    def get_tender_events(start_date, end_date)
      tenders = current_user_tenders.includes(:project_manager, :project)
      events = []
  
      tenders.each do |tender|
        # Tender deadline event
        if tender.deadline && tender.deadline.between?(start_date, end_date)
          days_until = (tender.deadline - Date.current).to_i
          priority = days_until <= 3 ? "high" : (days_until <= 7 ? "medium" : "low")
          
          events << {
            id: "tender_deadline_#{tender.id}",
            title: "#{tender.title} - Tender Deadline",
            description: tender.description || "Tender submission deadline",
            date: tender.deadline.strftime('%Y-%m-%d'),
            time: "23:59",
            type: "deadline",
            category: "tender",
            project: tender.project&.title || "New Project",
            project_id: tender.project_id,
            location: "Online Submission",
            attendees: [tender.project_manager&.name, tender.lead_person, tender.responsible].compact,
            status: "scheduled",
            priority: priority,
            color: "bg-yellow-500"
          }
        end
      end
  
      events
    end
  
    def get_direct_events(start_date, end_date)
      direct_events = Event.joins(:project)
                           .where(date: start_date..end_date)
                           .where(projects: { project_manager_id: current_user.id })
                           .includes(:project)
      
      events = []
  
      direct_events.each do |event|
        events << {
          id: "event_#{event.id}",
          title: event.description || "Project Event",
          description: event.description || "Scheduled project event",
          date: event.date.strftime('%Y-%m-%d'),
          time: "10:00", # Default time since events table doesn't have time
          type: "meeting",
          category: "event",
          project: event.project&.title || "Project Event",
          project_id: event.project_id,
          location: event.project&.location || "Project Site",
          attendees: [event.responsible, event.project&.project_manager&.name].compact,
          status: event.date < Date.current ? "completed" : "scheduled",
          priority: "medium",
          color: "bg-indigo-500"
        }
      end
  
      events
    end
  end