class ProjectManager < ApplicationRecord
    has_many :projects
    has_many :tenders
    has_many :events
    def self.busiest_manager
        joins(:projects).where(projects: { status: :ongoing }).group(:id).order('COUNT(projects.id) DESC').first
      end
  end
  