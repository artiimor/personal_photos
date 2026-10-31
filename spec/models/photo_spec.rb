require 'rails_helper'

RSpec.describe Photo, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }

    describe "image format" do
      let(:photo) { Photo.new(name: "beach", user: User.new) }

      # Active Storage sniffs the real content type from the bytes (Marcel), so
      # the declared content_type only wins when the bytes are not recognizable
      def attach(bytes, filename:, content_type:)
        photo.image.attach(io: StringIO.new(bytes), filename: filename, content_type: content_type)
      end

      it "is valid without an image" do
        expect(photo).to be_valid
      end

      {
        "jpeg" => [ Vips::Image.black(1, 1).jpegsave_buffer, "photo.jpg", "image/jpeg" ],
        "png" => [ Vips::Image.black(1, 1).pngsave_buffer, "photo.png", "image/png" ],
        "webp" => [ Vips::Image.black(1, 1).webpsave_buffer, "photo.webp", "image/webp" ],
        "heic" => [ "fake heic bytes", "photo.heic", "image/heic" ],
        "heif" => [ "fake heif bytes", "photo.heif", "image/heif" ]
      }.each do |format, (bytes, filename, content_type)|
        it "accepts #{format} images" do
          attach(bytes, filename: filename, content_type: content_type)

          expect(photo).to be_valid
        end
      end

      it "rejects files that are not images" do
        attach("just some text", filename: "notes.txt", content_type: "text/plain")

        expect(photo).not_to be_valid
        expect(photo.errors.of_kind?(:image, :invalid_type)).to be true
      end

      it "rejects image types outside the allowed list" do
        attach("GIF89a", filename: "anim.gif", content_type: "image/gif")

        expect(photo).not_to be_valid
        expect(photo.errors.of_kind?(:image, :invalid_type)).to be true
      end

      it "rejects a non-image disguised with an image extension and content type" do
        attach("%PDF-1.4\n", filename: "photo.jpg", content_type: "image/jpeg")

        expect(photo).not_to be_valid
        expect(photo.errors.of_kind?(:image, :invalid_type)).to be true
      end
    end
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
