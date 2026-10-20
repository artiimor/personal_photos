class ActiveStorage::Service::FileUploaderService < ActiveStorage::Service
  # TODO add error handling

  include HTTParty

  base_uri ENV.fetch("FILE_UPLOADER_URL")

  def upload(key, io, checksum: nil, **)
    owner_id = user_id_from_key(key)
    request("put",
            "/files/#{owner_id}",
            { query: { token: jwt_token(owner_id, "upload") },
              body: { file: io } })
  end

  def download(key, &block)
    request("get",
            "/files/#{key}",
            { query: { token: jwt_token(user_id_from_key(key), "download") } })
  end

  def exist?(key)
    true # TODO implement method in server first
  end

  def delete(key)
    bearer_request("delete",
            "files/#{key}")
  end

  def url(key, **options)
    # URL to upload file
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, **)
    request(:get, "/upload_url/#{user_id_from_key(key)}")
  end

  def headers_for_direct_upload(key, content_type:, **)
    {}
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{ENV.fetch('FILE_UPLOADER_API_TOKEN')}" }
  end

  def user_id_from_key(key)
    key.split("/", 2).first
  end

  def jwt_token(user_id, scope)
    secret = ENV.fetch("FILE_UPLOADER_JWT_TOKEN")
    JWT.encode(jwt_claims(user_id, scope), secret, "HS256")
  end

  def jwt_claims(user_id, scope)
    {
      sub: user_id,
      exp: (Time.now + 5 * 60).to_i,
      scope: scope
    }
  end

  def bearer_request(method, path, options = {})
    self.class.send(method, path, options.merge(headers: auth_headers))
  end

  def request(method, path, options = {})
    self.class.send(method, path, options)
  end
end
