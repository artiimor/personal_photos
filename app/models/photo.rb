class Photo < ApplicationRecord
  validates :name, presence: true
  validates :path, presence: true
  validates :file_type, presence: true

  has_one_attached :image do |a|
    a.variant :thumb, resize_to_limit: [ 300, 300 ], format: :webp, preprocessed: true
  end

  belongs_to :user
end
