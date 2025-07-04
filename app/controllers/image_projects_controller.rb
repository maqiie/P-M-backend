class ImageProjectsController < ApplicationController
    before_action :set_image_project, only: [:show, :edit, :update, :destroy]
  
    # GET /image_projects
    def index
      @image_projects = ImageProject.all
      render json: @image_projects
    end
  

    def show
        @image_project = ImageProject.find(params[:id])
        
        # Assuming `images` is an association with ActiveStorage blobs
        image_urls = @image_project.images.map do |image|
          rails_blob_path(image, only_path: true) # Generates the URL for the image
        end
    
        render json: {
          id: @image_project.id,
          name: @image_project.name,
          images: image_urls
        }
      end
      
  
    # GET /image_projects/new
    def new
      @image_project = ImageProject.new
      render json: @image_project
    end
  
    # POST /image_projects
    def create
        @image_project = ImageProject.new(image_project_params)
        if @image_project.save
          render json: @image_project, status: :created
        else
          render json: @image_project.errors, status: :unprocessable_entity
        end
      end
  
    # GET /image_projects/1/edit
    def edit
      render json: @image_project
    end
  
    # PATCH/PUT /image_projects/1
    def update
      if @image_project.update(image_project_params)
        render json: @image_project
      else
        render json: @image_project.errors, status: :unprocessable_entity
      end
    end
  
    # DELETE /image_projects/1
    def destroy
      @image_project.destroy
      head :no_content
    end
  
    private

    def image_project_params
      params.require(:image_project).permit(:name)
    end
      # Use callbacks to share common setup or constraints between actions.
      def set_image_project
        @image_project = ImageProject.find(params[:id])
      end
  
    #   # Only allow a list of trusted parameters through.
    #   def image_project_params
    #     params.require(:image_project).permit(:name, :description)
    #   end
  end
  
  