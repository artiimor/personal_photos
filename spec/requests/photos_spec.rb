require 'rails_helper'

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
          Photo.create!(name: "beach", path: "/photos/beach.jpg", file_type: "jpg", user: user).tap do |photo|
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
    let(:file) { fixture_file_upload("test_photo.jpg", "image/jpeg") }

    before { sign_in user }

    context "when the upload succeeds" do
      before do
        allow_any_instance_of(ActiveStorage::Service::FileUploaderService).to receive(:upload)
      end

      it "saves the photo for the current user and redirects to the index" do
        expect {
          post photos_path, params: { photo: { file: file } }
        }.to change { user.photos.count }.by(1)

        expect(response).to redirect_to(photos_path)
      end

      it "uploads the file under a key scoped to the user" do
        expect_any_instance_of(ActiveStorage::Service::FileUploaderService)
          .to receive(:upload)
          .with(a_string_starting_with("#{user.uid}/"), an_instance_of(File), hash_including(content_type: "image/jpeg"))

        post photos_path, params: { photo: { file: file } }
      end
    end

    context "when the photo fails to save" do
      it "never calls the upload service and does not redirect" do
        allow_any_instance_of(Photo).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(Photo.new))

        service = instance_double(ActiveStorage::Service::FileUploaderService)
        allow(ActiveStorage::Service::FileUploaderService).to receive(:new).and_return(service)
        expect(service).not_to receive(:upload)

        post photos_path, params: { photo: { file: file } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when the upload fails" do
      before do
        allow_any_instance_of(ActiveStorage::Service::FileUploaderService)
          .to receive(:upload).and_raise(ActiveStorage::FileNotFoundError)
      end

      it "rolls back the photo (transaction) and re-renders the form" do
        expect {
          post photos_path, params: { photo: { file: file } }
        }.not_to change { user.photos.count }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
