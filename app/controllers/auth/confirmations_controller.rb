class Auth::ConfirmationsController < Devise::ConfirmationsController
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      set_flash_message!(:notice, :confirmed)
      
      # Redirect to frontend login page with query param
      redirect_to frontend_login_url(confirmed: true)
    else
      respond_with_navigational(resource.errors, status: :unprocessable_entity) { render :new }
    end
  end

  private

  # Frontend login URL with optional query parameters
  def frontend_login_url(params = {})
    uri = URI.parse("https://p-m-dashboard.vercel.app/login")
    uri.query = params.to_query if params.any?
    uri.to_s
  end
end


# class Auth::ConfirmationsController < Devise::ConfirmationsController
#   def show
#     self.resource = resource_class.confirm_by_token(params[:confirmation_token])

#     if resource.errors.empty?
#       set_flash_message!(:notice, :confirmed)
#       respond_with_navigational(resource) { redirect_to confirmation_success_path }
#     else
#       respond_with_navigational(resource.errors, status: :unprocessable_entity) { render :new }
#     end
#   end

#   def confirmation_success
#     render 'devise/confirmations/success'
#   end

#   private

#   def confirmation_success_path
#     users_confirmation_success_path
#   end
# end