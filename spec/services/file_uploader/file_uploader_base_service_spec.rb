require "rails_helper"

RSpec.describe FileUploader::FileUploaderBaseService do
  let(:user) { instance_double(User, id: 1) }

  it "cannot be instantiated directly" do
    expect { described_class.new(user) }.to raise_error(NotImplementedError)
  end

  it "raises when user is blank" do
    expect { FileUploader::FileUploaderGetUploadUrlService.new(nil) }
      .to raise_error(ArgumentError, "user is required")
  end
end
