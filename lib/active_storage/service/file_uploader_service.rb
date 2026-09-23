class FileUploaderService < ActiveStorage::Service
  # TODO add error handling

  include HTTParty

  base_uri ENV.fetch("FILE_UPLOADER_URL")

  def upload(key, io, checksum: nil, **)
    request("put",
            "files/#{Current.user_id}",
            { query: { token: jwt_token("upload") },
              body: { file: io } })
  end

  def download(key, &block)
    request("get",
            "files/#{Current.user_id}/#{key}",
            { query: { token: jwt_token("download") } })
  end

  def exist?(key)
    True # TODO implement method in server first
  end

  def delete(key)
    bearer_request("delete",
            "files/#{Current.user_id}/#{key}")
  end

  def url(key, **options)
    # URL to upload file
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, **)
    request(:get, "/upload_url/#{Current.user_id}")
  end

  def headers_for_direct_upload(key, content_type:, **)
    {}
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

  def bearer_request(method, path, options = {})
    self.class.send(method, path, options.merge(headers: auth_headers))
  end

  def request
    self.class.send(method, path, options)
  end
end
