class FileUploaderService < ActiveStorage::Service
  include HTTParty

  def upload(key, io, checksum: nil, **)
    # POST/PUT file to my server
  end

  def download(key, &block)
    # GET file from my server
  end

  def exist?(key)
  end

  def delete(key)
  end

  def url(key, **options)
    # URL to upload file
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, **)
    # la URL a la que el navegador sube directo (subida directa)
  end

  def headers_for_direct_upload(key, content_type:, **)
  end

  private

  def jwt_token
    ENV.fetch("FILE_UPLOADER_JWT_TOKEN")
  end

  def request(method, path, options = {})
    self.class.send(method, path, options.merge(headers: auth_headers))
  end
end
