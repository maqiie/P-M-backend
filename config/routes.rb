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
  
  get 'project_managers/list', to: 'project_managers#list'

  # Project Managers namespace routes
  namespace :project_managers do
    get 'dashboard'
    get 'my_projects'
    get 'upcoming_events'
    get 'my_tenders'
    get 'statistics'
    get 'team_members'
    get 'projects_progress'

# get '/project_managers/list', to: 'project_managers#list'

    
    resources :tasks

    # Progress management routes
    patch 'projects/:id/update_progress', to: 'project_managers#update_progress', as: 'update_project_progress'
    get 'projects/:id/progress', to: 'project_managers#show_progress', as: 'show_project_progress'
    get 'projects/:id/progress_history', to: 'project_managers#progress_history', as: 'project_progress_history'
  end

  resources :projects do
    collection do
      get 'active'              
      get 'completed'           
      get 'chart_data'
      get 'my_projects'
      get 'progress_summary'
      get 'dashboard_progress'
    end
    
    member do
      get 'progress'
      get 'progress_history'
      get 'team'
      get 'timeline'
      get 'progress_trends'
      get 'progress_details'
      
      patch 'update_progress', to: 'projects#update_progress'
      put 'update_progress', to: 'projects#update_progress'
    end
    
    
    # Nested events routes inside projects
    resources :events, except: [:index] do
      collection do
        get 'upcoming'
      end
    end
  end

  # Events routes (non-nested)
  resources :events do
    collection do
      get 'my_events'
      get 'upcoming'
      get 'this_week'
    end
    
    member do
      patch 'mark_completed'
      patch 'reschedule'
    end
  end

  # Tenders routes
  resources :tenders do
    collection do
      get 'my_tenders'
      get 'active'
      get 'urgent'
      get 'drafts'
    end
    
    member do
      post 'convert_to_project'
      patch 'update_status'
      get 'details'
    end
  end

  # Supervisors routes
  resources :supervisors do
    collection do
      get 'workload'
    end
    
    member do
      get 'projects'
      get 'performance'
    end
  end

  # Other resources - UPDATED SECTION
  resources :tasks do
    collection do
      get :statistics
    end
  end
  resources :custom_fields
  resources :site_managers, only: [:index, :show, :create, :update, :destroy]
  resources :project_managers

  # Dashboard routes
  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/overview', to: 'dashboard#overview'
  get 'dashboard/analytics', to: 'dashboard#analytics'
  get 'dashboard/projects_progress', to: 'dashboard#projects_progress'  # New route

  # API namespace v1
  namespace :api do
    namespace :v1 do
      get 'dashboard/quick_stats'
      get 'dashboard/recent_activities'
      get 'dashboard/notifications'
      get 'dashboard/projects_progress'  # New API endpoint
      
      resources :projects, only: [:index, :show] do
        collection do
          get 'search'
          get 'filters'
          get 'with_progress'  # New endpoint for projects with progress
        end
        
        member do
          get 'progress'
          patch 'update_progress'
          get 'progress_history'
        end
      end
      
      get 'live_updates/projects'
      get 'live_updates/events'
      get 'live_updates/tenders'
      get 'live_updates/progress'  # New live updates for progress
    end
  end

  # Progress-specific routes (consolidated)
  namespace :progress do
    resources :updates, only: [:create, :index, :show]
    resources :reports, only: [:index, :show]
    get 'dashboard/:project_id', to: 'dashboard#show'
    get 'summary', to: 'dashboard#summary'
  end

  # Reports and analytics
  namespace :reports do
    get 'projects/summary'
    get 'projects/timeline'
    get 'projects/budget'
    get 'projects/progress'    # New progress report
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

  # Notifications
  resources :notifications, only: [:index, :show, :update] do
    collection do
      patch 'mark_all_read'
      get 'unread_count'
    end
    
    member do
      patch 'mark_read'
    end
  end

  # Search
  get 'search', to: 'search#index'
  get 'search/projects', to: 'search#projects'
  get 'search/events', to: 'search#events'
  get 'search/tenders', to: 'search#tenders'

  # Calendar integration
  get 'calendar', to: 'calendar#index'
  get 'calendar/events', to: 'calendar#events'
  get 'calendar/month/:year/:month', to: 'calendar#month'

  # Teams management
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

  resources :activities, only: [:index, :show] do
    collection do
      # Optional custom routes for additional filtering or stats
      get 'stats'       # e.g. /activities/stats for summary statistics
      get 'recent'      # e.g. /activities/recent for latest activities
    end
  end
  # Legacy routes (keep if needed)
  get "/tenders", to: 'application#tenders'

  # Health and status checks
  get 'health', to: 'application#health'
  get 'status', to: 'application#status'

# config/routes.rb
# get 'project_managers/list', to: 'project_managers#list'

  # Calendar integration
get 'calendar', to: 'calendar#index'
get 'calendar/events', to: 'calendar#events'
get 'calendar/month/:year/:month', to: 'calendar#month'
end
