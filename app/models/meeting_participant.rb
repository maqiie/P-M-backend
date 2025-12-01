# app/models/meeting_participant.rb
class MeetingParticipant < ApplicationRecord
  belongs_to :meeting
  belongs_to :user

  def respond!(new_status)
    update(status: new_status, responded_at: Time.current)
  end
end