


require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DeviseTokenAuthTwitter
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2


# In config/application.rb or an appropriate environment file (e.g., config/environments/development.rb)
config.active_record.encryption.key_derivation_salt = "ea889532a15e4f2cbe34c895a8671a110a901386f85a0f9a83e767f2ae2e1e722e44663ea1d2c1abf3fdad14e97efcbf6df8039f22419aa9087ff0760854c106"
config.active_record.encryption.primary_key = "6854706591f80e5c416950d9197aa31adc8d97e044fa16cff7b5e23b69042d6d"
    
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    # config.middleware.use ActionDispatch::Session::CookieStore
    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.

    config.generators.system_tests = nil
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # ここからコピペする
    config.session_store :cookie_store, key: '_interslice_session'
    config.middleware.use ActionDispatch::Cookies # Required for all session management
    config.middleware.use ActionDispatch::Session::CookieStore, config.session_options
    config.middleware.use ActionDispatch::Flash


    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*',
                 :headers => :any,
                 :expose => ['access-token', 'expiry', 'token-type', 'uid', 'client'],
                 :methods => [:get, :post, :options, :delete, :put, :patch]
      end
    end
    # ここまで
  end
end

