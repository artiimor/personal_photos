require 'rails_helper'

RSpec.describe Photo, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "thumb variant" do
    let(:user) { User.create!(email: "user@example.com", password: "password123") }
    # a real (if tiny) JPEG, since the thumb variant actually gets decoded/resized by vips
    let(:real_jpeg) { Vips::Image.black(20, 20).jpegsave_buffer }

    before do
      allow_any_instance_of(ActiveStorage::Service::FileUploaderService).to receive(:upload)
      allow_any_instance_of(ActiveStorage::Service::FileUploaderService).to receive(:download) do |&block|
        block ? block.call(real_jpeg) : real_jpeg
      end
    end

    let!(:photo) do
      Photo.create!(name: "beach", user: user).tap do |photo|
        photo.image.attach(
          key: "#{user.id}/original",
          io: StringIO.new(real_jpeg),
          filename: "test_photo.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    it "scopes the generated thumb's blob key to the photo owner (regression: variant key lost the user_id prefix)" do
      variant_blob = photo.image.variant(:thumb).processed.image.blob

      expect(variant_blob.key).to start_with("#{user.id}/")
    end
  end
end
