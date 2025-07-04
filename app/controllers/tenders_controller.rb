class TendersController < ApplicationController

def index
    @tenders=Tender.all
    render json: @tenders
end


    def create
      @tender = Tender.new(tender_params)
      if @tender.save
        render json: @tender, status: :created
      else
        render json: @tender.errors, status: :unprocessable_entity
      end
    end

    def convert_to_project
        @tender = Tender.find(params[:id])
    
        # Create a new project with details from the tender
        @project = Project.new(
          title: @tender.title,
          description: @tender.description, # You can copy description if needed
          deadline: @tender.deadline, # Set the deadline or any other relevant details
          project_manager_id: @tender.project_manager_id,
          lead_person: @tender.lead_person,
          responsible: @tender.responsible,
          location: 'Unknown', # Set default or specific location if needed
          finishing_date: @tender.deadline # Example of setting finishing_date based on tender's deadline
        )
    
        if @project.save
          # Optionally, you can mark the tender as converted or delete it
          @tender.destroy # If you want to delete the tender after conversion
    
          flash[:success] = 'Tender successfully converted to project.'
          redirect_to @project
        else
          flash[:error] = 'Failed to convert tender to project.'
          redirect_to @tender
        end
      end
  
    private
  
    def tender_params
      params.require(:tender).permit(:title, :description, :deadline, :lead_person, :responsible, :project_id, :project_manager_id, :created_at, :updated_at)
    end
  end
  