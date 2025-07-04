

class ApplicationController < ActionController::Base
  # before_action :configure_permitted_parameters, if: :devise_controller?
  skip_before_action :verify_authenticity_token
  after_action :set_cors_headers


  include DeviseTokenAuth::Concerns::SetUserByToken

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: "Access denied."
  end
  
  def confirm_email
    confirmation_token = params[:confirmation_token]
    user = User.find_by(confirmation_token: confirmation_token)

    if user
      user.confirm # Assuming Devise's `confirm` method, which you might need to adjust
      redirect_to users_confirmation_success_path, notice: "Email confirmed successfully!"
    else
      redirect_to root_path, alert: "Invalid confirmation token."
    end
  end

  def confirmation_success
    render 'users/confirmation_success'
  end
  
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:otp_attempt])
  end

   # Define CORS headers after every action - safely add Authorization to exposed headers
   after_action :set_cors_headers

   def set_cors_headers
     existing = response.headers['Access-Control-Expose-Headers']
     # Headers your frontend needs to access for DeviseTokenAuth
     needed_headers = ['access-token', 'expiry', 'token-type', 'uid', 'client', 'Authorization']
 
     if existing.present?
       existing_headers = existing.split(',').map(&:strip)
       merged_headers = (existing_headers + needed_headers).uniq
       response.headers['Access-Control-Expose-Headers'] = merged_headers.join(', ')
     else
       response.headers['Access-Control-Expose-Headers'] = needed_headers.join(', ')
     end
   end
 
  

end
