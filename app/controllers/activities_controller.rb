class ActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @activities = Activity.includes(:actor, :target)

    # Filter by target_type (e.g., 'Project', 'Task', 'Tender')
    if params[:type].present?
      @activities = @activities.where(target_type: params[:type].capitalize)
    end

    # Filter by actor_id (optional)
    if params[:actor_id].present?
      @activities = @activities.where(actor_id: params[:actor_id])
    end

    # Filter by date range (created_at)
    if params[:start_date].present?
      @activities = @activities.where('created_at >= ?', Date.parse(params[:start_date]))
    end

    if params[:end_date].present?
      @activities = @activities.where('created_at <= ?', Date.parse(params[:end_date]).end_of_day)
    end

    # Sorting: default newest first, allow asc or desc
    sort_dir = params[:sort_direction]&.downcase == 'asc' ? 'asc' : 'desc'
    @activities = @activities.order(created_at: sort_dir)

    # Limit the number of records returned (to prevent huge payloads)
    limit = params[:limit].to_i > 0 ? [params[:limit].to_i, 100].min : 20
    @activities = @activities.limit(limit)

    render json: {
      activities: @activities.as_json(include: {
        actor: { only: [:id, :name, :email] },
        target: { only: [:id, :title, :name] }
      }),
      pagination: {
        total_count: @activities.size,
        limit: limit
      }
    }
  end

  private

  def require_admin!
    unless current_user.admin?
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end
end
