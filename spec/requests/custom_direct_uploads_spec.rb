require 'rails_helper'

RSpec.describe "CustomDirectUploads", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }
  let(:blob_params) do
    {
      filename: "test_photo.jpg",
      content_type: "image/jpeg",
      byte_size: 123,
      checksum: Digest::MD5.base64digest("data")
    }
  end

  describe "#create" do
    context "when not signed in" do
      it "does not create a blob and does not raise" do
        expect {
          post "/rails/active_storage/direct_uploads", params: { blob: blob_params }, as: :json
        }.not_to change { ActiveStorage::Blob.count }

        expect(response).not_to have_http_status(:internal_server_error)
      end
    end

    context "when signed in" do
      before do
        sign_in user
        allow_any_instance_of(ActiveStorage::Service::FileUploaderService)
          .to receive(:url_for_direct_upload).and_return("http://example.com/upload")
      end

      it "scopes the created blob's key to the current user" do
        post "/rails/active_storage/direct_uploads", params: { blob: blob_params }, as: :json

        expect(response).to be_successful
        expect(ActiveStorage::Blob.last.key).to start_with("#{user.id}/")
      end
    end
  end
end
