
  # class Auth::SessionsController < DeviseTokenAuth::SessionsController
  #   def create
  #     user = User.find_by(email: params[:email])
  
  #     if user&.valid_password?(params[:password])
  #       assign_role_if_admin(user)
  
  #       if user.otp_required_for_login
  #         if send_otp(user)
  #           render json: { message: 'OTP is required for login', otp_required: true }, status: :accepted
  #         else
  #           render json: { errors: ['Error sending OTP'] }, status: :internal_server_error
  #         end
  #       else
  #         # Use DeviseTokenAuth to sign in
  #         super
  #       end
  #     else
  #       render json: { errors: ['Invalid login credentials'] }, status: :unauthorized
  #     end
  #   end
  
  #   def verify_otp
  #     user = User.find_by(email: params[:email])
  
  #     if user && user.valid_otp?(params[:otp])
  #       sign_in(user, store: false)
  
  #       # Create new auth token
  #       auth_tokens = user.create_new_auth_token
  #       auth_tokens[:role] = user.role
  #       auth_tokens[:user] = {
  #         email: user.email,
  #         role: user.role,
  #         id: user.id
  #       }
  
  #       render json: auth_tokens, status: :ok
  #     else
  #       render json: { error: 'Invalid OTP' }, status: :unprocessable_entity
  #     end
  #   end
  
  #   private
  
  #   def send_otp(user)
  #     user.send_new_otp
  #     true
  #   rescue => e
  #     Rails.logger.error "Error sending OTP to #{user.email}: #{e.message}"
  #     false
  #   end
  
  #   def assign_role_if_admin(user)
  #     if user.id == 1 && user.role != 'admin'
  #       if user.update(role: 'admin')
  #         Rails.logger.info "Assigned admin role to first user ID: #{user.id}"
  #       else
  #         Rails.logger.error "Failed to assign admin role to user ID: #{user.id}: #{user.errors.full_messages.join(', ')}"
  #       end
  #     end
  #   end
  # end
  

  class Auth::SessionsController < DeviseTokenAuth::SessionsController
    def create
      user = User.find_by(email: params[:email])
  
      if user&.valid_password?(params[:password])
        assign_role_if_admin(user)
  
        if user.otp_required_for_login
          if send_otp(user)
            log_activity(user, "login_attempt", method: "otp", status: "otp_sent")
            render json: { message: 'OTP is required for login', otp_required: true }, status: :accepted
          else
            log_activity(user, "login_attempt", method: "otp", status: "otp_failed")
            render json: { errors: ['Error sending OTP'] }, status: :internal_server_error
          end
        else
          log_activity(user, "login", method: "password", status: "success")
          super
        end
      else
        log_activity(user, "login", method: "password", status: "failed") if user
        render json: { errors: ['Invalid login credentials'] }, status: :unauthorized
      end
    end
  
    def verify_otp
      user = User.find_by(email: params[:email])
  
      if user && user.valid_otp?(params[:otp])
        sign_in(user, store: false)
  
        log_activity(user, "login", method: "otp", status: "success")
  
        # Create new auth token
        auth_tokens = user.create_new_auth_token
        auth_tokens[:role] = user.role
        auth_tokens[:user] = {
          email: user.email,
          role: user.role,
          id: user.id
        }
  
        render json: auth_tokens, status: :ok
      else
        log_activity(user, "login", method: "otp", status: "failed") if user
        render json: { error: 'Invalid OTP' }, status: :unprocessable_entity
      end
    end
  
    private
  
    def send_otp(user)
      user.send_new_otp
      true
    rescue => e
      Rails.logger.error "Error sending OTP to #{user.email}: #{e.message}"
      false
    end
  
    def assign_role_if_admin(user)
      if user.id == 1 && user.role != 'admin'
        if user.update(role: 'admin')
          Rails.logger.info "Assigned admin role to first user ID: #{user.id}"
        else
          Rails.logger.error "Failed to assign admin role to user ID: #{user.id}: #{user.errors.full_messages.join(', ')}"
        end
      end
    end
  
    def log_activity(user, action, metadata = {})
      Activity.create!(
        actor: user,
        action: action,
        target: user,
        target_type: "User",
        metadata: metadata.merge(ip: request.remote_ip)
      )
    end
  end
  