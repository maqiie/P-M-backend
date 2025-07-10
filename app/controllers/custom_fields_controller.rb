class CustomFieldsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_custom_field, only: [:show, :update, :destroy]
  
    # GET /custom_fields
    def index
      @custom_fields = CustomField.all
      
      # Filter by entity type if provided
      if params[:entity_type].present?
        @custom_fields = @custom_fields.where(entity_type: params[:entity_type])
      end
      
      render json: { custom_fields: @custom_fields }
    end
  
    # GET /custom_fields/:id
    def show
      render json: @custom_field
    end
  
    # POST /custom_fields
    def create
      @custom_field = CustomField.new(custom_field_params)
      
      if @custom_field.save
        render json: @custom_field, status: :created
      else
        render json: { errors: @custom_field.errors.full_messages }, status: :unprocessable_entity
      end
    end
  
    # PUT/PATCH /custom_fields/:id
    def update
      if @custom_field.update(custom_field_params)
        render json: @custom_field
      else
        render json: { errors: @custom_field.errors.full_messages }, status: :unprocessable_entity
      end
    end
  
    # DELETE /custom_fields/:id
    def destroy
      @custom_field.destroy
      render json: { message: 'Custom field deleted successfully' }
    end
  
    private
  
    def set_custom_field
      @custom_field = CustomField.find(params[:id])
    end
  
    def custom_field_params
      params.require(:custom_field).permit(
        :name, :field_type, :description, :required, :entity_type,
        options: {}
      )
    end
  end