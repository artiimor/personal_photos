class CustomDirectUploadsController < ActiveStorage::DirectUploadsController
  before_action :authenticate_user!
  def create
    custom_key = generate_custom_key(params[:blob])

    blob = ActiveStorage::Blob.create_before_direct_upload!(
      key: custom_key,
      **blob_args
    )

    render json: direct_upload_json(blob)
  end

  private

  def generate_custom_key(blob_params)
    ext = Marcel::Magic.new(blob_params[:content_type]).extensions.first || "bin"
    "#{current_user.id}/#{SecureRandom.uuid}.#{ext}"
  end
end
