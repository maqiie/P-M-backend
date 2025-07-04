class ImagesController < ApplicationController
    before_action :set_image_project, only: [:create]
  
    # Upload images

    def create
        if params[:images].present?
          params[:images].each do |image|
            @image_project.images.attach(image)
          end
    
          if @image_project.save
            render json: { images: @image_project.images.map { |img| { id: img.id, filename: img.filename.to_s } } }, status: :ok
          else
            render json: { errors: @image_project.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { error: 'No images provided' }, status: :unprocessable_entity
        end
      end
    # Show a specific image
    def show
      @image = Image.find(params[:id])
      
      if @image.image.attached?
        # Use Active Storage's built-in methods to serve the image
        redirect_to rails_blob_path(@image.image, disposition: "inline")
      else
        render json: { error: "Image not found" }, status: :not_found
      end
    end
  
    # List all images
    def index
      @images = Image.all
      render json: @images.as_json(only: [:id, :created_at], methods: [:image_url])
    end
  
    private
    
    def set_image_project
        @image_project = ImageProject.find(params[:image_project_id])
      end
  
    
  
    # Strong parameters for images
    def images_params
      params.require(:images).map do |image|
        image.permit(:image)
      end
    end
  end
  