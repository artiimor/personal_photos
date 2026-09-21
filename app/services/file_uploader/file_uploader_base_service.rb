module FileUploader
  class FileUploaderBaseService
    include HTTParty

    base_uri ENV.fetch("FILE_UPLOADER_URL")

    def initialize(user)
      raise NotImplementedError, "#{self.class} is abstract, instantiate a subclass" if instance_of?(FileUploaderBaseService)

      raise ArgumentError, "user is required" if user.blank?
      @user = user
    end

    private

    def request(method, path, options = {})
      self.class.send(method, path, options.merge(headers: auth_headers))
    end

    def auth_headers
      { "Authorization" => "Bearer #{ENV.fetch('FILE_UPLOADER_API_TOKEN')}" }
    end
  end
end
