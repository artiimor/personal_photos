module FileUploader
  class FileUploaderGetUploadUrlService < FileUploaderBaseService
    def call
      response = request(:get, "/upload_url/#{@user.id}") # TODO En el futuro se devolvera un JSON y no un string a pelo
      return nil unless response.code == 200 # TODO better error handling wtf

      response
    end
  end
end
