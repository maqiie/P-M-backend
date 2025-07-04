class UserMailer < ApplicationMailer
    default from: 'noreply@example.com'
  
    def otp_email(user, otp_code)
      @user = user
      @otp_code = otp_code
      mail(to: @user.email, subject: 'Your OTP Code')
    end
  end
  