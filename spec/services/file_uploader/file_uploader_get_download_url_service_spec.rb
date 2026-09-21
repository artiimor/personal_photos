require "rails_helper"

RSpec.describe FileUploader::FileUploaderGetDownloadUrlService do
  let(:user) { instance_double(User, id: 1) }

  describe "#initialize" do
    it "does not raise when file_name is blank, but leaves the instance unusable" do
      # `initialize`'s return value is ignored by Ruby, so `.new` still hands back
      # an instance - just one that blows up as soon as #call touches @user.
      service = described_class.new(user, "")

      expect { service.call }.to raise_error(NoMethodError)
    end
  end

  describe "#call" do
    subject(:service) { described_class.new(user, "photo.jpg") }

    it "returns the response when the request succeeds" do
      response = instance_double(HTTParty::Response, code: 200, body: "https://example.com/download")
      allow(described_class).to receive(:get).with("/download_url/1/photo.jpg", anything).and_return(response)

      expect(service.call).to eq(response)
    end

    it "returns nil when the request does not succeed" do
      response = instance_double(HTTParty::Response, code: 404, body: "not found")
      allow(described_class).to receive(:get).with("/download_url/1/photo.jpg", anything).and_return(response)

      expect(service.call).to be_nil
    end
  end
end
