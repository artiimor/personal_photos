class ActiveStorage::Service::FileUploaderService < ActiveStorage::Service
  include HTTParty

  base_uri ENV.fetch("FILE_UPLOADER_URL")

  def upload(key, io, checksum: nil, content_type: nil, **)
    # Check this. Its used for the thumb service and the name is so weird
    owner_id = user_id_from_key(key)
    file_name = synthetic_filename(key, content_type)
    io.define_singleton_method(:original_filename) { file_name }

    request("put",
            "/files/#{owner_id}/#{file_name}",
            { query: { token: jwt_token(owner_id, "upload", file_name) },
              body: { file: io } })
  end

  def download(key, &block)
    file_name = synthetic_filename(key, ActiveStorage::Blob.find_by(key: key)&.content_type)

    response = request("get",
                        "/files/#{user_id_from_key(key)}/#{file_name}",
                        { query: { token: jwt_token(user_id_from_key(key), "download", file_name) } })
    block_given? ? yield(response.body) : response.body
  end

  # TODO it downloads the entire file. Implement headers Range en el servidor de rails para no descargarlo todo...  
  def download_chunk(key, range)
    download(key).byteslice(range)
  end

  def exist?(key)
    true # TODO implement method in server first
  end

  def delete(key)
    bearer_request("delete", path_with_filename(key))
  end

  # Browser-facing URL: the Rails server reaches the file-uploader via FILE_UPLOADER_URL
  # (e.g. host.docker.internal inside the app container), but that host is only resolvable
  # from inside the container, not from the end user's browser following the redirect.
  def url(key, content_type: nil, **options)
    file_name = synthetic_filename(key, content_type)
    "#{public_base_uri}/files/#{user_id_from_key(key)}/#{file_name}?token=#{jwt_token(user_id_from_key(key), "download", file_name)}"
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, **)
    puts "Old school debug"
    puts key
    user_id = user_id_from_key(key)
    file_id = synthetic_filename(key, content_type)

    response = bearer_request(:get, "/upload_url/#{user_id}/#{file_id}")
    puts "pinga"
    puts response.body

    "#{public_base_uri}#{handle_response(response).body}"
  end

  def headers_for_direct_upload(key, content_type:, **)
    { "Content-Type": content_type }
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{ENV.fetch('FILE_UPLOADER_API_TOKEN')}" }
  end

  def user_id_from_key(key)
    key.split("/", 2).first
  end

  def public_base_uri
    ENV.fetch("FILE_UPLOADER_PUBLIC_URL", self.class.base_uri)
  end

  def path_with_filename(key)
    content_type = ActiveStorage::Blob.find_by(key: key)&.content_type
    "/files/#{user_id_from_key(key)}/#{synthetic_filename(key, content_type)}"
  end

  def synthetic_filename(key, content_type)
    basename = key.to_s.split("/").last
    ext = content_type.to_s.split("/").last.presence || "bin"
    "#{basename}.#{ext}"
  end

  def jwt_token(user_id, scope, file_name)
    secret = ENV.fetch("FILE_UPLOADER_JWT_TOKEN")
    JWT.encode(jwt_claims(user_id, scope, file_name), secret, "HS256")
  end

  def jwt_claims(user_id, scope, file_name)
    {
      sub: user_id,
      exp: (Time.now + 5 * 60).to_i,
      scope: scope,
      file_name: file_name
    }
  end

  def bearer_request(method, path, options = {})
    response = self.class.send(method, path, options.merge(headers: auth_headers))
    handle_response(response)
  end

  def request(method, path, options = {})
    response = self.class.send(method, path, options)
    handle_response(response)
  end

  def handle_response(response)
    case response.code.to_i
    when 200..299 then response
    when 404      then raise ActiveStorage::FileNotFoundError
    when 422      then raise ActiveStorage::IntegrityError
    when 401, 403 then raise ActiveStorage::Error, "JWT rejected (#{response.code})"
    else               raise ActiveStorage::Error, "File server #{response.code}"
    end
  end
end
