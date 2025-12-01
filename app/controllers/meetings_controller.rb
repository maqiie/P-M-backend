# app/controllers/meetings_controller.rb
class MeetingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_meeting, only: [:show, :update, :destroy]
  before_action :require_admin!, only: [:create, :update, :destroy]

  # GET /meetings
  def index
    if current_user.admin?
      @meetings = Meeting.includes(:created_by, :project, :participants)
    else
      # Regular users only see meetings they're invited to
      @meetings = Meeting.for_user(current_user).includes(:created_by, :project, :participants)
    end

    # Filters
    case params[:filter]
    when 'upcoming'
      @meetings = @meetings.upcoming
    when 'past'
      @meetings = @meetings.past
    when 'today'
      @meetings = @meetings.today
    end

    @meetings = @meetings.where(status: params[:status]) if params[:status].present?
    @meetings = @meetings.order(meeting_date: :desc)

    render json: { meetings: @meetings.map { |m| meeting_json(m) } }
  end

  # GET /meetings/:id
  def show
    render json: meeting_json(@meeting)
  end

  # POST /meetings (Admin only)
  def create
    @meeting = Meeting.new(meeting_params)
    @meeting.created_by = current_user

    if @meeting.save
      # Add participants and send notifications
      if params[:meeting][:participant_ids].present?
        params[:meeting][:participant_ids].each do |user_id|
          user = User.find_by(id: user_id)
          next unless user
          
          @meeting.add_participant(user)
          
          # Create notification
          Notification.create(
            user: user,
            title: 'New Meeting Invitation',
            message: "You've been invited to '#{@meeting.title}' on #{@meeting.meeting_date.strftime('%B %d, %Y at %I:%M %p')}",
            notification_type: 'meeting_invitation'
          )
          
          # Send email
          MeetingMailer.invitation_email(@meeting, user).deliver_now
        end
      end

      # Add creator as participant
      @meeting.add_participant(current_user)

      render json: meeting_json(@meeting), status: :created
    else
      render json: { errors: @meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /meetings/:id (Admin only)
  def update
    old_participants = @meeting.participant_ids

    if @meeting.update(meeting_params)
      # Handle participant changes
      if params[:meeting][:participant_ids].present?
        new_ids = params[:meeting][:participant_ids].map(&:to_i)
        
        # Add new participants
        (new_ids - old_participants).each do |user_id|
          user = User.find_by(id: user_id)
          next unless user
          
          @meeting.add_participant(user)
          Notification.create(
            user: user,
            title: 'New Meeting Invitation',
            message: "You've been invited to '#{@meeting.title}'",
            notification_type: 'meeting_invitation'
          )
          MeetingMailer.invitation_email(@meeting, user).deliver_now
        end

        # Remove old participants
        (old_participants - new_ids).each do |user_id|
          user = User.find_by(id: user_id)
          @meeting.remove_participant(user) if user
        end
      end

      # Notify existing participants of updates
      @meeting.participants.each do |participant|
        next if participant == current_user
        Notification.create(
          user: participant,
          title: 'Meeting Updated',
          message: "Meeting '#{@meeting.title}' has been updated",
          notification_type: 'meeting_updated'
        )
      end

      render json: meeting_json(@meeting)
    else
      render json: { errors: @meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /meetings/:id (Admin only)
  def destroy
    # Notify participants
    @meeting.participants.each do |participant|
      next if participant == current_user
      Notification.create(
        user: participant,
        title: 'Meeting Cancelled',
        message: "Meeting '#{@meeting.title}' has been cancelled",
        notification_type: 'meeting_cancelled'
      )
      MeetingMailer.cancelled_email(@meeting, participant).deliver_now
    end

    @meeting.destroy
    render json: { message: 'Meeting deleted successfully' }
  end

  # POST /meetings/:id/respond (Any participant)
  def respond_to_meeting
    @meeting = Meeting.find(params[:id])
    participant = @meeting.meeting_participants.find_by(user: current_user)
    
    if participant
      participant.respond!(params[:response])
      
      # Notify admin
      Notification.create(
        user: @meeting.created_by,
        title: 'Meeting Response',
        message: "#{current_user.name} has #{params[:response]} the meeting '#{@meeting.title}'",
        notification_type: 'meeting_response'
      )
      
      render json: { message: 'Response recorded', status: participant.status }
    else
      render json: { error: 'You are not a participant' }, status: :forbidden
    end
  end

  private

  def require_admin!
    unless current_user.admin?
      render json: { error: 'Admin access required' }, status: :forbidden
    end
  end

  def set_meeting
    @meeting = Meeting.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Meeting not found' }, status: :not_found
  end

 def meeting_params
  params.require(:meeting).permit(
    :title, :description, :meeting_date, :location, :meeting_type,
    :status, :project_id, :duration_minutes, :meeting_link, :notes, :agenda,
    participant_ids: []   # ← ADD THIS
  )
end


  def meeting_json(meeting)
    {
      id: meeting.id,
      title: meeting.title,
      description: meeting.description,
      meeting_date: meeting.meeting_date&.iso8601,
      location: meeting.location,
      meeting_type: meeting.meeting_type,
      status: meeting.status,
      duration_minutes: meeting.duration_minutes,
      meeting_link: meeting.meeting_link,
      notes: meeting.notes,
      agenda: meeting.agenda,
      project: meeting.project ? { id: meeting.project.id, title: meeting.project.title } : nil,
      created_by: {
        id: meeting.created_by.id,
        name: meeting.created_by.name,
        email: meeting.created_by.email
      },
      participants: meeting.meeting_participants.includes(:user).map do |mp|
        {
          id: mp.user.id,
          name: mp.user.name,
          email: mp.user.email,
          status: mp.status,
          is_required: mp.is_required,
          responded_at: mp.responded_at&.iso8601
        }
      end,
      created_at: meeting.created_at&.iso8601,
      updated_at: meeting.updated_at&.iso8601
    }
  end
end