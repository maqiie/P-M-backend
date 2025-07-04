class SiteManager < ApplicationRecord
    validates :name, presence: true
    validates :email, presence: true, uniqueness: true
    
    enum status: { active: 0, inactive: 1 }
    enum availability: { available: 0, busy: 1, vacation: 2 }
    
    # Store certifications as JSON array
    serialize :certifications, JSON
    
    # Associations
    has_many :projects, foreign_key: 'site_manager_id', dependent: :nullify
    
    # Scopes
    scope :active, -> { where(status: :active) }
    scope :available, -> { where(availability: :available) }
  end