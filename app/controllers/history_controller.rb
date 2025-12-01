# app/controllers/history_controller.rb
class HistoryController < ApplicationController
  before_action :authenticate_user!

  # GET /history
  def index
    if current_user.admin?
      completed_projects = Project.where(status: 'completed').order(updated_at: :desc).limit(20)
      completed_tasks = Task.where(status: 'completed').includes(:project, :user).order(updated_at: :desc).limit(30)
    else
      completed_projects = current_user.managed_projects.where(status: 'completed').order(updated_at: :desc).limit(20)
      completed_tasks = current_user.all_tasks.where(status: 'completed').includes(:project, :user).order(updated_at: :desc).limit(30)
    end

    render json: {
      completed_projects: completed_projects.map { |p| project_history(p) },
      completed_tasks: completed_tasks.map { |t| task_history(t) },
      milestones: milestones
    }
  end

  # GET /history/timeline
  def timeline
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    activities = []

    if current_user.admin?
      projects = Project.where(status: 'completed', updated_at: start_date.beginning_of_day..end_date.end_of_day)
      tasks = Task.where(status: 'completed', updated_at: start_date.beginning_of_day..end_date.end_of_day).includes(:user, :project)
      meetings = Meeting.where(status: 'completed', meeting_date: start_date.beginning_of_day..end_date.end_of_day)
    else
      projects = current_user.managed_projects.where(status: 'completed', updated_at: start_date.beginning_of_day..end_date.end_of_day)
      tasks = current_user.all_tasks.where(status: 'completed', updated_at: start_date.beginning_of_day..end_date.end_of_day).includes(:user, :project)
      meetings = Meeting.for_user(current_user).where(status: 'completed', meeting_date: start_date.beginning_of_day..end_date.end_of_day)
    end

    projects.each do |p|
      activities << {
        type: 'project_completed',
        icon: 'building',
        title: "Project completed: #{p.title}",
        date: p.updated_at,
        data: { id: p.id, title: p.title, budget: p.budget }
      }
    end

    tasks.each do |t|
      activities << {
        type: 'task_completed',
        icon: 'check',
        title: "Task completed: #{t.title}",
        date: t.updated_at,
        data: { id: t.id, title: t.title, user: t.user&.name, project: t.project&.title }
      }
    end

    meetings.each do |m|
      activities << {
        type: 'meeting_completed',
        icon: 'users',
        title: "Meeting held: #{m.title}",
        date: m.meeting_date,
        data: { id: m.id, title: m.title, participants: m.participants.count }
      }
    end

    activities.sort_by! { |a| a[:date] }.reverse!

    render json: { timeline: activities }
  end

  private

  def milestones
    if current_user.admin?
      {
        total_projects_completed: Project.where(status: 'completed').count,
        total_tasks_completed: Task.where(status: 'completed').count,
        total_budget_managed: Project.where(status: 'completed').sum(:budget) || 0,
        total_meetings_held: Meeting.where(status: 'completed').count,
        total_users: User.count
      }
    else
      {
        total_projects_completed: current_user.managed_projects.where(status: 'completed').count,
        total_tasks_completed: current_user.all_tasks.where(status: 'completed').count,
        total_budget_managed: current_user.managed_projects.where(status: 'completed').sum(:budget) || 0,
        meetings_attended: Meeting.for_user(current_user).where(status: 'completed').count
      }
    end
  end

  def project_history(project)
    {
      id: project.id,
      title: project.title,
      description: project.description,
      status: project.status,
      progress: project.progress_percentage,
      budget: project.budget,
      location: project.location,
      start_date: project.start_date,
      end_date: project.finishing_date,
      completed_at: project.updated_at
    }
  end

  def task_history(task)
    {
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      project: task.project ? { id: task.project.id, title: task.project.title } : nil,
      user: task.user ? { id: task.user.id, name: task.user.name } : nil,
      due_date: task.due_date,
      completed_at: task.updated_at
    }
  end
end