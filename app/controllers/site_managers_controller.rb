# app/controllers/site_managers_controller.rb
class SiteManagersController < ApplicationController
    before_action :set_site_manager, only: [:show, :update, :destroy]
    
    def index
      @site_managers = SiteManager.all
      render json: @site_managers
    end
    
    def show
      render json: @site_manager
    end
    
    def create
      @site_manager = SiteManager.new(site_manager_params)
      
      if @site_manager.save
        render json: @site_manager, status: :created
      else
        render json: @site_manager.errors, status: :unprocessable_entity
      end
    end
    
    def update
      if @site_manager.update(site_manager_params)
        render json: @site_manager
      else
        render json: @site_manager.errors, status: :unprocessable_entity
      end
    end
    
    def destroy
      @site_manager.destroy
      head :no_content
    end
    
    private
    
    def set_site_manager
      @site_manager = SiteManager.find(params[:id])
    end
    
    def site_manager_params
      params.require(:site_manager).permit(:name, :email, :phone, :location, 
                                          :specialization, :experience_years, 
                                          :status, :availability, certifications: [])
    end
  end