class FileUploaderService < ActiveStorage::Service
  include HTTParty

  def upload(key, io, checksum: nil, **)
    # POST/PUT file to my server need to obtain the user_id
    request("put",
            "files/#{Current.user_id}",
            { query: { token: jwt_token("upload") },
              body: { file: io } })
  end

  def download(key, &block)
    # GET file from my server
    request("get",
            "files/#{Current.user_id}/#{key}",
            { query: { token: jwt_token("download") } })
  end

  def exist?(key)
  end

  def delete(key)
    request("delete",
            "files/#{Current.user_id}/#{key}")
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

  def auth_headers
    { "Authorization" => "Bearer #{ENV.fetch('FILE_UPLOADER_API_TOKEN')}" }
  end


  def jwt_token(scope)
    secret = ENV.fetch("FILE_UPLOADER_JWT_TOKEN")
    JWT.encode(jwt_claims(scope), secret, "HS256")
  end

  def jwt_claims(scope)
    {
      sub: Current.user_id,
      exp: (Time.now + 5 * 60).to_i,
      scope: scope
    }
  end

  def request(method, path, options = {})
    self.class.send(method, path, options.merge(headers: auth_headers)) if method == "/delete"

    self.class.send(method, path, options)
  end
end
