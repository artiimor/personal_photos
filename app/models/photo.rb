class Photo < ApplicationRecord
  validates :name, presence: true

  has_one_attached :image do |image|
    image.variant :thumb, resize_to_limit: [ 300, 300 ], format: :webp
  end

  belongs_to :user
end
