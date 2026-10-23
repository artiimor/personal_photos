class CustomDirectUploadsController < ActiveStorage::DirectUploadsController
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
    "#{current_user.id}/#{SecureRandom.uuid}"
  end
end
