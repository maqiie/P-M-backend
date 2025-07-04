class Image < ApplicationRecord
    belongs_to :image_project
    has_one_attached :file

     # Method to generate URL for the image

     validates :file, presence: true

  def image_url
    Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true) if image.attached?
  end
  end
  