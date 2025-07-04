class ImageProject < ApplicationRecord
    has_many :images, dependent: :destroy
    has_many_attached :images

  end
  

