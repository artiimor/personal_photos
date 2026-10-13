require "rails_helper"

RSpec.describe ActiveStorage::Service::FileUploaderService do
  subject(:service) { described_class.new }

  let(:owner_id) { "42" }
  let(:key) { "#{owner_id}/abc123" }
  let(:secret) { ENV.fetch("FILE_UPLOADER_JWT_TOKEN") }

  def decoded_claims(token)
    JWT.decode(token, secret, true, algorithm: "HS256").first
  end

  describe "#user_id_from_key" do
    it "extracts the owner id (first key segment)" do
      expect(service.send(:user_id_from_key, key)).to eq(owner_id)
    end
  end

  describe "#jwt_token" do
    it "encodes a token with the given sub, scope and a 5 minute expiry" do
      before_exp = 5.minutes.from_now.to_i
      token = service.send(:jwt_token, owner_id, "download")
      after_exp = 5.minutes.from_now.to_i
      claims = decoded_claims(token)

      expect(claims["sub"]).to eq(owner_id)
      expect(claims["scope"]).to eq("download")
      expect(claims["exp"]).to be_between(before_exp, after_exp)
    end
  end

  describe "#upload" do
    it "PUTs to the owner's single-segment path with an upload-scoped token" do
      allow(described_class).to receive(:put)

      service.upload(key, StringIO.new("data"))

      expect(described_class).to have_received(:put) do |path, options|
        expect(path).to eq("files/#{owner_id}")
        expect(decoded_claims(options[:query][:token])).to include(
          "sub" => owner_id, "scope" => "upload"
        )
        expect(options[:body]).to include(file: an_instance_of(StringIO))
      end
    end
  end

  describe "#download" do
    it "GETs the full key path with a download-scoped token" do
      allow(described_class).to receive(:get)

      service.download(key)

      expect(described_class).to have_received(:get) do |path, options|
        expect(path).to eq("files/#{key}")
        expect(decoded_claims(options[:query][:token])).to include(
          "sub" => owner_id, "scope" => "download"
        )
      end
    end
  end

  describe "#delete" do
    it "DELETEs the full key path with the bearer API token (no JWT)" do
      allow(described_class).to receive(:delete)

      service.delete(key)

      expect(described_class).to have_received(:delete).with(
        "files/#{key}",
        hash_including(headers: { "Authorization" => "Bearer #{ENV.fetch('FILE_UPLOADER_API_TOKEN')}" })
      )
    end
  end

  describe "#url_for_direct_upload" do
    it "GETs the owner's single-segment upload_url path" do
      allow(described_class).to receive(:get)

      service.url_for_direct_upload(
        key, expires_in: 5.minutes, content_type: "image/png",
        content_length: 10, checksum: "x"
      )

      expect(described_class).to have_received(:get).with("/upload_url/#{owner_id}", {})
    end
  end

  describe "#exist?" do
    it "returns true" do
      expect(service.exist?(key)).to eq(true)
    end
  end
end
