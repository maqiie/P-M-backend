# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  before_action :authenticate_user!

  # GET /reports/overview
  def overview
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    if current_user.admin?
      projects = Project.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      tasks = Task.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    else
      projects = current_user.managed_projects.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      tasks = current_user.all_tasks.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end

    render json: {
      summary: {
        total_projects: projects.count,
        completed_projects: projects.where(status: 'completed').count,
        active_projects: projects.where(status: ['active', 'in_progress']).count,
        total_tasks: tasks.count,
        completed_tasks: tasks.where(status: 'completed').count,
        pending_tasks: tasks.where(status: 'pending').count,
        overdue_tasks: tasks.where('due_date < ? AND status != ?', Date.current, 'completed').count,
        total_budget: projects.sum(:budget) || 0,
        avg_project_progress: projects.average(:progress_percentage)&.round(2) || 0
      },
      projects_by_status: projects.group(:status).count,
      tasks_by_status: tasks.group(:status).count,
      tasks_by_priority: tasks.group(:priority).count,
      projects_by_month: projects.group_by { |p| p.created_at.strftime('%Y-%m') }.transform_values(&:count),
      tasks_by_month: tasks.group_by { |t| t.created_at.strftime('%Y-%m') }.transform_values(&:count)
    }
  end

  # GET /reports/projects
  def projects
    start_date = params[:start_date]&.to_date || 1.year.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    if current_user.admin?
      projects = Project.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    else
      projects = current_user.managed_projects.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end

    # Top project managers (admin only)
    top_managers = []
    if current_user.admin?
      top_managers = User.joins(:managed_projects)
                         .where(projects: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                         .group('users.id', 'users.name', 'users.email')
                         .select('users.id, users.name, users.email, COUNT(projects.id) as project_count')
                         .order('project_count DESC')
                         .limit(10)
                         .map { |u| { id: u.id, name: u.name, email: u.email, project_count: u.project_count } }
    end

    render json: {
      total: projects.count,
      by_status: projects.group(:status).count,
      completed: projects.where(status: 'completed').count,
      total_budget: projects.sum(:budget) || 0,
      avg_progress: projects.average(:progress_percentage)&.round(2) || 0,
      top_managers: top_managers,
      recent_completed: projects.where(status: 'completed')
                                .order(updated_at: :desc)
                                .limit(10)
                                .map { |p| project_summary(p) }
    }
  end

  # GET /reports/tasks
  def tasks
    start_date = params[:start_date]&.to_date || 1.year.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    if current_user.admin?
      tasks = Task.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    else
      tasks = current_user.all_tasks.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end

    completed = tasks.where(status: 'completed')
    completion_rate = tasks.count > 0 ? ((completed.count.to_f / tasks.count) * 100).round(2) : 0

    render json: {
      total: tasks.count,
      by_status: tasks.group(:status).count,
      by_priority: tasks.group(:priority).count,
      completed: completed.count,
      overdue: tasks.where('due_date < ? AND status != ?', Date.current, 'completed').count,
      completion_rate: completion_rate
    }
  end

  # GET /reports/users (Admin only)
  def users
    unless current_user.admin?
      return render json: { error: 'Admin access required' }, status: :forbidden
    end

    start_date = params[:start_date]&.to_date || 1.year.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current

    users = User.includes(:managed_projects, :owned_tasks)

    render json: {
      total_users: users.count,
      admins: users.where(role: 'admin').count,
      regular_users: users.where(role: 'user').count,
      user_performance: users.limit(20).map { |u| user_performance(u, start_date, end_date) }
    }
  end

  private

  def project_summary(project)
    {
      id: project.id,
      title: project.title,
      status: project.status,
      progress: project.progress_percentage,
      budget: project.budget,
      location: project.location,
      completed_at: project.updated_at
    }
  end

  def user_performance(user, start_date, end_date)
    user_tasks = user.owned_tasks.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    user_projects = user.managed_projects.where(created_at: start_date.beginning_of_day..end_date.end_of_day)

    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      tasks_created: user_tasks.count,
      tasks_completed: user_tasks.where(status: 'completed').count,
      projects_managed: user_projects.count,
      projects_completed: user_projects.where(status: 'completed').count
    }
  end
end