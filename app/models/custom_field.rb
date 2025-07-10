class CustomField < ApplicationRecord
    validates :name, presence: true, uniqueness: { scope: :entity_type }
    validates :field_type, inclusion: { 
      in: %w[text long_text number currency date checkbox dropdown user] 
    }
    validates :entity_type, inclusion: { in: %w[task project tender] }
  
    def self.for_entity(entity_type)
      where(entity_type: entity_type)
    end
  
    def dropdown_options
      return [] unless field_type == 'dropdown'
      options&.dig('values') || []
    end
  
    def required?
      required == true
    end
  end