class Photo < ApplicationRecord
  validates :name, presence: true
  validates :path, presence: true
  validates :file_type, presence: true

  belongs_to :user
end
