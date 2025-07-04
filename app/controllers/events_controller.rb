class EventsController < ApplicationController

def index
  @events = Event.all
  render json: @events
end

  def create
    @event = Event.new(event_params)
    if @event.save
      render json: @event, status: :created
    else
      Rails.logger.error("Failed to create event: #{@event.errors.full_messages.join(', ')}")
      render json: @event.errors, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error("Error creating event: #{e.message}")
    render json: { error: 'Internal Server Error' }, status: :internal_server_error
  end

  private

  def event_params
    params.require(:event).permit(:description, :date, :project_id, :responsible)
  end
end
