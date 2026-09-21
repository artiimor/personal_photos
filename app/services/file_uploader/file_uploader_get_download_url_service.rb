module FileUploader
  class FileUploaderGetDownloadUrlService < FileUploaderBaseService
    def initialize(user, file_name)
      return "file name is required" if file_name.blank?
      @file_name = file_name

      super(user)
    end

    def call
      response = request(:get, "/download_url/#{@user.id}/#{@file_name}") # TODO En el futuro se devolvera un JSON y no un string a pelo
      return nil unless response.code == 200 # TODO better error handling wtf

      response
    end
  end
end
