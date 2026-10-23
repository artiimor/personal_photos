class PhotosController < ApplicationController
  before_action :authenticate_user!

  def index
    @photos = current_user.photos
  end

  def new
    @photo = current_user.photos.new
  end

  def create
    uploaded_file = photo_params[:file]
    key = "#{current_user.uid}/#{SecureRandom.uuid}"

    @photo = current_user.photos.new(
      name: uploaded_file.original_filename,
      path: key,
      file_type: uploaded_file.content_type
    )

    ActiveRecord::Base.transaction do
      @photo.save!
      @photo.image.attach(
        key: key,
        io: uploaded_file.open,
        filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type
      )
    end

    redirect_to photos_path, notice: t("photos.create.success")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  rescue ActiveStorage::Error => e
    Rails.logger.error("[PhotosController#create] upload failed: #{e.class} - #{e.message}")
    @photo.errors.add(:base, t("photos.create.failure", error: e.message))
    render :new, status: :unprocessable_entity
  end

  private

  def photo_params
    params.require(:photo).permit(:file)
  end
end
