
class User < ActiveRecord::Base
  devise :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :two_factor_authenticatable,
         otp_secret_encryption_key: ENV['OTP_SECRET_ENCRYPTION_KEY']

  include DeviseTokenAuth::Concerns::User

  before_create :generate_otp_secret, unless: :otp_secret?

  has_many :projects
  has_many :tenders
  has_many :events
  has_many :roles
  enum role: { user: 0, admin: 1 }
  has_many :managed_projects, class_name: 'Project', foreign_key: 'project_manager_id'
  has_many :tasks, foreign_key: :project_manager_id, dependent: :destroy


  def project_manager?
    role == 'user'
  end

  def send_new_otp
    otp_code = current_otp
    Rails.logger.info "Sending OTP email to: #{email}, OTP code: #{otp_code}"
    UserMailer.otp_email(self, otp_code).deliver_now
  end

  def current_otp
    ROTP::TOTP.new(otp_secret).now
  end

  def valid_otp?(otp)
    Rails.logger.info "Verifying OTP: #{otp}, Expected OTP: #{current_otp}"
    ROTP::TOTP.new(otp_secret).verify(otp, drift_behind: 30) # Allow a 30-second drift
  end

  private

  def generate_otp_secret
    return if otp_secret.present?

    self.otp_secret = ROTP::Base32.random_base32
    self.otp_required_for_login = true
    Rails.logger.info "Generated OTP secret for user: #{email}, OTP secret: #{otp_secret}"
  end
end

