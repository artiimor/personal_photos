class PhotosController < ApplicationController
  before_action :authenticate_user!

  def index
    @photos = current_user.photos
  end

  def new
    @photo = current_user.photos.new
  end

  def create
    # Make sure we only accept upload in the browser
    file = photo_params[:file]
    return head :unprocessable_entity unless file.is_a?(String)

    @photo = current_user.photos.new
    @photo.image.attach(file)

    blob = @photo.image.blob
    @photo.name = blob.filename.to_s

    @photo.save!

    redirect_to photos_path, notice: t("photos.create.success")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  rescue ActiveStorage::Error => e
    @photo.destroy if @photo&.persisted?
    Rails.logger.error("[PhotosController#create] upload failed: #{e.class} - #{e.message}")
    @photo.errors.add(:base, t("photos.create.failure", error: e.message))
    render :new, status: :unprocessable_entity
  end

  private

  def photo_params
    params.require(:photo).permit(:file)
  end
end
