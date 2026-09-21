require "rails_helper"

RSpec.describe FileUploader::FileUploaderGetUploadUrlService do
  let(:user) { instance_double(User, id: 1) }

  subject(:service) { described_class.new(user) }

  describe "#call" do
    it "returns the response when the request succeeds" do
      response = instance_double(HTTParty::Response, code: 200, body: "https://example.com/upload")
      allow(described_class).to receive(:get).with("/upload_url/1", anything).and_return(response)

      expect(service.call).to eq(response)
    end

    it "returns nil when the request does not succeed" do
      response = instance_double(HTTParty::Response, code: 500, body: "boom")
      allow(described_class).to receive(:get).with("/upload_url/1", anything).and_return(response)

      expect(service.call).to be_nil
    end
  end
end
