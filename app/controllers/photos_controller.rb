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
    service = ActiveStorage::Service::FileUploaderService.new

    @photo = current_user.photos.new(
      name: uploaded_file.original_filename,
      path: key,
      file_type: uploaded_file.content_type
    )

    ActiveRecord::Base.transaction do
      @photo.save!
      service.upload(key, uploaded_file)
    end

    redirect_to photos_path, notice: t("photos.create.success")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  rescue ActiveStorage::Error => e
    @photo.errors.add(:base, t("photos.create.failure", error: e.message))
    render :new, status: :unprocessable_entity
  end

  private

  def photo_params
    params.require(:photo).permit(:file)
  end
end
