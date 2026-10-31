class Photo < ApplicationRecord
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze

  validates :name, presence: true

  validate :correct_image_file_format
  validate :blob_starts_with_user_id

  has_one_attached :image do |image|
    image.variant :thumb, resize_to_limit: [ 300, 300 ], format: :webp
  end

  belongs_to :user

  private

  def correct_image_file_format
    return unless image.attached?
    errors.add(:image, :invalid_type) unless ALLOWED_TYPES.include?(image.blob.content_type)
  end

  def blob_starts_with_user_id
    return unless image.attached?
    return unless user.present?

    blob = image.blob

    unless blob.key.start_with?("#{user_id}/")
      errors.add(:image, :invalid_user, message: "no pertenece a este usuario")
    end
  end
end
