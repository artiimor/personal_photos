require 'rails_helper'

RSpec.describe "Photos", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }

  describe "GET /index" do
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
          expect(response.body).to include("Aún no se han subido fotos")
        end
      end

      context "with photos" do
        let!(:photo) { Photo.create!(name: "beach", path: "/photos/beach.jpg", file_type: "jpg", user: user) }

        it "lists the user's photos" do
          get photos_path
          expect(response.body).to include(photo.name)
        end
      end
    end
  end
end
