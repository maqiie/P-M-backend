
Rails.application.routes.draw do
  # Authentication routes
  mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    registrations: 'auth/registrations',
    sessions: 'auth/sessions'
  }

  devise_scope :user do
    post "/auth/verify_otp" => "auth/sessions#verify_otp"
    get 'users/confirmation_success', to: 'application#confirmation_success', as: :users_confirmation_success
    get 'users/email_confirmed', to: 'application#email_confirmed'
    get 'users/confirm_email', to: 'application#confirm_email', as: 'confirm_email'
  end

  # Project Manager Dashboard Routes
  resources :project_managers do
    collection do
      get 'dashboard'           # Main dashboard data
      get 'my_projects'         # Projects managed by current user
      get 'upcoming_events'     # Upcoming events for PM's projects
      get 'my_tenders'          # Tenders assigned to PM
      get 'statistics'          # Dashboard statistics
      get 'team_members'        # Team member statistics
      get 'projects_progress'   # Project progress overview
    end
  end

  # Projects routes with enhanced functionality
  resources :projects do
    collection do
      get 'chart_data'          # Chart data for analytics
      get 'my_projects'         # Alternative route for current user's projects
    end
    
    member do
      get 'progress'            # Individual project progress
      patch 'update_progress'   # Update project progress
      get 'team'                # Project team members
      get 'timeline'            # Project timeline/milestones
    end
    
    # Nested resources for project-specific data
    resources :events, except: [:index] do
      collection do
        get 'upcoming'          # Upcoming events for this project
      end
    end
  end

  # Events routes with project manager context
  resources :events do
    collection do
      get 'my_events'           # Events for PM's projects
      get 'upcoming'            # All upcoming events
      get 'this_week'           # Events for current week
    end
    
    member do
      patch 'mark_completed'    # Mark event as completed
      patch 'reschedule'        # Reschedule event
    end
  end

  # Tenders routes with enhanced functionality
  resources :tenders do
    collection do
      get 'my_tenders'          # Tenders for current PM
      get 'active'              # Active tenders
      get 'urgent'              # Urgent tenders (deadline soon)
      get 'drafts'              # Draft tenders
    end
    
    member do
      post 'convert_to_project' # Convert tender to project
      patch 'update_status'     # Update tender status
      get 'details'             # Detailed tender view
    end
  end

  # Supervisors routes
  resources :supervisors do
    collection do
      get 'workload'            # Supervisor workload data
    end
    
    member do
      get 'projects'            # Projects under this supervisor
      get 'performance'         # Supervisor performance metrics
    end
  end


  resources :tasks


  # Dashboard routes (can be used for different user types)
  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/overview', to: 'dashboard#overview'
  get 'dashboard/analytics', to: 'dashboard#analytics'

  # API routes for dashboard widgets
  namespace :api do
    namespace :v1 do
      get 'dashboard/quick_stats'
      get 'dashboard/recent_activities'
      get 'dashboard/notifications'
      
      # Project-specific API endpoints
      resources :projects, only: [:index, :show] do
        collection do
          get 'search'
          get 'filters'
        end
      end
      
      # Real-time updates
      get 'live_updates/projects'
      get 'live_updates/events'
      get 'live_updates/tenders'
    end
  end

  # Reports and Analytics
  namespace :reports do
    get 'projects/summary'
    get 'projects/timeline'
    get 'projects/budget'
    get 'team/performance'
    get 'team/workload'
    get 'tenders/conversion_rate'
    get 'tenders/success_rate'
  end

  # Image and file management
  resources :images, only: [:create, :show, :index] do
    collection do
      post 'bulk_upload'
      delete 'bulk_delete'
    end
  end
  
  resources :image_projects do
    resources :images, only: [:create]
  end

  # Notification routes
  resources :notifications, only: [:index, :show, :update] do
    collection do
      patch 'mark_all_read'
      get 'unread_count'
    end
    
    member do
      patch 'mark_read'
    end
  end

  # Search functionality
  get 'search', to: 'search#index'
  get 'search/projects', to: 'search#projects'
  get 'search/events', to: 'search#events'
  get 'search/tenders', to: 'search#tenders'

  # Calendar integration
  get 'calendar', to: 'calendar#index'
  get 'calendar/events', to: 'calendar#events'
  get 'calendar/month/:year/:month', to: 'calendar#month'

  # Team management
  resources :teams, only: [:index, :show] do
    member do
      get 'schedule'
      get 'performance'
      post 'assign_project'
      delete 'remove_project'
    end
  end

  # Settings and preferences
  resources :settings, only: [:index, :update] do
    collection do
      get 'profile'
      patch 'update_profile'
      get 'notifications'
      patch 'update_notifications'
      get 'preferences'
      patch 'update_preferences'
    end
  end

  # Legacy routes (keep for backward compatibility)
  get "/tenders", to: 'application#tenders'

  # Health check and status
  get 'health', to: 'application#health'
  get 'status', to: 'application#status'

  resources :supervisors, only: [:index, :show, :create, :update, :destroy]
  resources :site_managers, only: [:index, :show, :create, :update, :destroy]
  # Catch-all route for SPA (if using React Router)
  # get '*path', to: 'application#index', constraints: ->(req) { !req.xhr? && req.format.html? }

  resources :projects do
    collection do
      get 'chart_data'          # Your existing route
      get 'my_projects'         # Your existing route
      get 'progress_summary'    # ADD THIS NEW ROUTE
    end
    
    member do
      get 'progress'            # ADD THIS NEW ROUTE  
      patch 'update_progress'   # ADD THIS NEW ROUTE
      get 'progress_history'    # ADD THIS NEW ROUTE
      get 'team'                # Your existing route (if you have it)
      get 'timeline'            # Your existing route (if you have it)
    end
    
end

