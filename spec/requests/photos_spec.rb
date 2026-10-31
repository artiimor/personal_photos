require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe "Photos", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }

  describe "#index" do
    context "when not signed in" do
      it "redirects to sign in" do
        get photos_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns a successful response" do
        get photos_path
        expect(response).to be_successful
      end

      context "with no photos" do
        it "shows a message saying no photos have been uploaded" do
          get photos_path
          expect(response.body).to include("No photos have been uploaded yet.")
        end
      end

      context "with photos" do
        before { allow_any_instance_of(ActiveStorage::Service::FileUploaderService).to receive(:upload) }

        let!(:photo) do
          Photo.create!(name: "beach", user: user).tap do |photo|
            photo.image.attach(fixture_file_upload("test_photo.jpg", "image/jpeg"))
          end
        end

        it "lists the user's photos" do
          get photos_path
          expect(response.body).to include(photo.name)
        end
      end
    end
  end

  describe "#new" do
    it "redirects to sign in when not signed in" do
      get new_photo_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns a successful response when signed in" do
      sign_in user
      get new_photo_path
      expect(response).to be_successful
    end
  end

  describe "#create" do
    before { sign_in user }

    context "with a direct-uploaded blob (signed_id)" do
      let(:blob) do
        ActiveStorage::Blob.create_before_direct_upload!(
          key: "#{user.uid}/#{SecureRandom.uuid}.jpg",
          filename: "test_photo.jpg",
          byte_size: 123,
          checksum: Digest::MD5.base64digest("data"),
          content_type: "image/jpeg"
        )
      end

      # attaching by signed_id identifies the blob, which downloads its first bytes
      before do
        allow_any_instance_of(ActiveStorage::Service::FileUploaderService)
          .to receive(:download).and_return(file_fixture("test_photo.jpg").binread)
      end

      it "saves the photo named after the blob and redirects to the index" do
        expect {
          post photos_path, params: { photo: { file: blob.signed_id } }
        }.to change { user.photos.count }.by(1)

        expect(user.photos.last.name).to eq("test_photo.jpg")
        expect(response).to redirect_to(photos_path)
      end

      it "attaches the existing user-scoped blob without uploading again" do
        expect_any_instance_of(ActiveStorage::Service::FileUploaderService).not_to receive(:upload)

        post photos_path, params: { photo: { file: blob.signed_id } }

        expect(user.photos.last.image.blob).to eq(blob)
      end

      context "when the file uploader fails" do
        [ ActiveStorage::Error, Errno::ECONNREFUSED ].each do |failure|
          it "renders the form with 422 and saves no photo (#{failure})" do
            allow_any_instance_of(ActiveStorage::Service::FileUploaderService)
              .to receive(:download).and_raise(failure)

            expect {
              post photos_path, params: { photo: { file: blob.signed_id } }
            }.not_to change { user.photos.count }

            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end

    context "with a multipart file" do
      let(:file) { fixture_file_upload("test_photo.jpg", "image/jpeg") }

      it "rejects it without creating a photo, a blob or uploading anything" do
        expect_any_instance_of(ActiveStorage::Service::FileUploaderService).not_to receive(:upload)

        expect {
          post photos_path, params: { photo: { file: file } }
        }.to not_change { user.photos.count }.and not_change { ActiveStorage::Blob.count }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "#thumb" do
    let(:other_user) { User.create!(email: "other@example.com", password: "password123") }
    let(:photo) do
      Photo.create!(name: "beach", user: user).tap do |photo|
        photo.image.attach(
          key: "#{user.id}/#{SecureRandom.uuid}.jpg",
          io: file_fixture("test_photo.jpg").open,
          filename: "test_photo.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    before do
      allow_any_instance_of(ActiveStorage::Service::FileUploaderService).to receive(:upload)
      allow_any_instance_of(ActiveStorage::VariantWithRecord)
        .to receive(:processed).and_return(double(url: "http://files.example.com/thumb.webp"))
    end

    it "redirects to sign in when not signed in" do
      get thumb_photo_path(photo)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects the owner to the file server thumbnail" do
      sign_in user
      get thumb_photo_path(photo)
      expect(response).to redirect_to("http://files.example.com/thumb.webp")
    end

    it "returns 404 for another user's photo without touching the file" do
      expect_any_instance_of(ActiveStorage::VariantWithRecord).not_to receive(:processed)

      sign_in other_user
      get thumb_photo_path(photo)
      expect(response).to have_http_status(:not_found)
    end
  end
end
