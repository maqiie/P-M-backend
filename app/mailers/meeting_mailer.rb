# app/mailers/meeting_mailer.rb
class MeetingMailer < ApplicationMailer
  default from: 'noreply@yourapp.com'

  def invitation_email(meeting, user)
    @meeting = meeting
    @user = user
    mail(to: user.email, subject: "Meeting Invitation: #{meeting.title}")
  end

  def updated_email(meeting, user)
    @meeting = meeting
    @user = user
    mail(to: user.email, subject: "Meeting Updated: #{meeting.title}")
  end

  def cancelled_email(meeting, user)
    @meeting = meeting
    @user = user
    mail(to: user.email, subject: "Meeting Cancelled: #{meeting.title}")
  end
end