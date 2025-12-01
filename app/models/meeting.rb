# app/models/meeting.rb
class Meeting < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  belongs_to :project, optional: true
  
  has_many :meeting_participants, dependent: :destroy
  has_many :participants, through: :meeting_participants, source: :user

  validates :title, presence: true
  validates :meeting_date, presence: true

  scope :upcoming, -> { where('meeting_date > ?', Time.current).where.not(status: 'cancelled').order(meeting_date: :asc) }
  scope :past, -> { where('meeting_date < ?', Time.current).order(meeting_date: :desc) }
  scope :today, -> { where(meeting_date: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :for_user, ->(user) { joins(:meeting_participants).where(meeting_participants: { user_id: user.id }) }

  def add_participant(user, is_required: true)
    meeting_participants.find_or_create_by(user: user) do |mp|
      mp.is_required = is_required
    end
  end

  def remove_participant(user)
    meeting_participants.find_by(user: user)&.destroy
  end
end