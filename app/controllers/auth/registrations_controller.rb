# class Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
#   include Devise::Controllers::Helpers
#   include Devise::Controllers::UrlHelpers

#   # Override the create method to handle email confirmation and 2FA setup after registration
#   def create
#         super do |resource|
#           # Check if the resource was successfully created
#           if resource.persisted?
#             # Set the @token instance variable to the confirmation_token
#             @token = resource.confirmation_token
#             # Send confirmation email if confirmation is required
#             if resource.confirmed?
#               resource.send_confirmation_instructions
#             end
            
#             # Initiate the 2FA setup process if it's required for login
#             resource.send_new_otp if resource.otp_required_for_login
#           end
#         end
#       end
#   private

#   def sign_up_params
#     params.require(:user).permit(:name, :username, :email, :password, :password_confirmation, :nickname, :role)
#   end
  
#   def configure_sign_up_params
#     devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :email, :password, :password_confirmation, :nickname,:role_id])
#   end
# end

class Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  include Devise::Controllers::Helpers
  include Devise::Controllers::UrlHelpers

  before_action :sanitize_admin_role, only: [:create]

  def create
    super do |resource|
      if resource.persisted?
        @token = resource.confirmation_token

        # Auto-promote first user to admin
        if User.count == 1 && resource.role != 'admin'
          resource.update(role: 'admin')
          Rails.logger.info "Auto-assigned admin role to first user: #{resource.email}"
        end

        # Send confirmation email if not already confirmed
        resource.send_confirmation_instructions unless resource.confirmed?

        # Setup OTP
        resource.send_new_otp if resource.otp_required_for_login
      end
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(
      :name, :username, :email, :password, :password_confirmation, :nickname, :role
    )
  end

  # Block attempts to register as admin unless allowed
  def sanitize_admin_role
    return unless params[:user][:role] == 'admin'

    if User.count == 0
      Rails.logger.info "First user registering as admin – allowed"
    elsif current_user&.admin?
      Rails.logger.info "Admin #{current_user.email} registering another admin – allowed"
    else
      Rails.logger.warn "Blocked unauthorized attempt to register as admin: #{params[:user][:email]}"
      render json: { error: 'You are not authorized to create an admin user.' }, status: :unauthorized
    end
  end
end
