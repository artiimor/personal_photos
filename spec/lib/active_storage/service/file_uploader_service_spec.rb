require "rails_helper"

RSpec.describe ActiveStorage::Service::FileUploaderService do
  include ActiveSupport::Testing::TimeHelpers

  subject(:service) { described_class.new }

  let(:owner_id) { "42" }
  let(:key) { "#{owner_id}/abc123.jpg" }
  let(:secret) { ENV.fetch("FILE_UPLOADER_JWT_TOKEN") }
  let!(:blob) { ActiveStorage::Blob.create!(key: key, filename: "photo.jpg", content_type: "image/jpeg", byte_size: 0, checksum: "d41d8cd98f00b204e9800998ecf8427e") }
  let(:synthetic_filename) { "abc123.jpg" }

  def decoded_claims(token)
    JWT.decode(token, secret, true, algorithm: "HS256").first
  end

  let(:success_response) { instance_double(HTTParty::Response, code: 200, body: "file-bytes") }

  describe "#user_id_from_key" do
    it "extracts the owner id (first key segment)" do
      expect(service.send(:user_id_from_key, key)).to eq(owner_id)
    end
  end

  describe "#jwt_token" do
    it "encodes a token with the given sub, scope and a 5 minute expiry" do
      before_exp = 5.minutes.from_now.to_i
      token = service.send(:jwt_token, owner_id, "download", "abc123.jpeg")
      after_exp = 5.minutes.from_now.to_i
      claims = decoded_claims(token)

      expect(claims["sub"]).to eq(owner_id)
      expect(claims["scope"]).to eq("download")
      expect(claims["exp"]).to be_between(before_exp, after_exp)
    end
  end

  describe "#upload" do
    it "PUTs to the user-scoped synthetic filename path with an upload-scoped token" do
      allow(described_class).to receive(:put).and_return(success_response)

      service.upload(key, StringIO.new("data"), content_type: "image/jpeg")

      expect(described_class).to have_received(:put) do |path, options|
        expect(path).to eq("/files/#{owner_id}/#{synthetic_filename}")
        expect(decoded_claims(options[:query][:token])).to include(
          "sub" => owner_id, "scope" => "upload"
        )
        expect(options[:body]).to include(file: an_instance_of(StringIO))
      end
    end

    it "returns the server's response on success" do
      allow(described_class).to receive(:put).and_return(success_response)

      expect(service.upload(key, StringIO.new("data"))).to eq(success_response)
    end

    it "signs the upload token for the same user_id used in the path (regression: owner_id/user_id rename)" do
      allow(described_class).to receive(:put).and_return(success_response)

      service.upload(key, StringIO.new("data"))

      expect(described_class).to have_received(:put) do |_path, options|
        expect(decoded_claims(options[:query][:token])["sub"]).to eq(owner_id)
      end
    end
  end

  describe "#download" do
    it "GETs the user-scoped synthetic filename path with a download-scoped token" do
      allow(described_class).to receive(:get).and_return(success_response)

      service.download(key)

      expect(described_class).to have_received(:get) do |path, options|
        expect(path).to eq("/files/#{owner_id}/#{synthetic_filename}")
        expect(decoded_claims(options[:query][:token])).to include(
          "sub" => owner_id, "scope" => "download"
        )
      end
    end

    it "returns the response body on success" do
      allow(described_class).to receive(:get).and_return(success_response)

      expect(service.download(key)).to eq("file-bytes")
    end

    it "yields the response body to a block instead of returning it" do
      allow(described_class).to receive(:get).and_return(success_response)
      yielded = nil

      service.download(key) { |chunk| yielded = chunk }

      expect(yielded).to eq("file-bytes")
    end
  end

  describe "#delete" do
    it "DELETEs the user-scoped synthetic filename path with the bearer API token (no JWT)" do
      allow(described_class).to receive(:delete).and_return(success_response)

      service.delete(key)

      expect(described_class).to have_received(:delete).with(
        "/files/#{owner_id}/#{synthetic_filename}",
        hash_including(headers: { "Authorization" => "Bearer #{ENV.fetch('FILE_UPLOADER_API_TOKEN')}" })
      )
    end

    it "returns the server's response on success" do
      allow(described_class).to receive(:delete).and_return(success_response)

      expect(service.delete(key)).to eq(success_response)
    end
  end

  describe "#url_for_direct_upload" do
    let(:uri) { ENV["FILE_UPLOADER_PUBLIC_URL"] || ENV["FILE_UPLOADER_URL"] }
    let(:secret) { ENV.fetch("FILE_UPLOADER_JWT_TOKEN") }
    let(:jwt_claims) {
      {
        sub: owner_id,
        exp: (Time.now + 5 * 60).to_i,
        scope: "upload",
        file_name: synthetic_filename
      }
    }
    let(:token) { JWT.encode(jwt_claims, secret, "HS256") }
    let(:correct_upload_url) { "#{uri}/#{key}?token=#{token}" }

    before {
      freeze_time
    }

    it "GETs the owner's upload_url path for the synthesized filename, with the bearer token" do
      url = service.url_for_direct_upload(
        key, expires_in: 5.minutes, content_type: "image/png",
        content_length: 10, checksum: "x"
      )

      expect(url).to eq(correct_upload_url)
    end
  end

  describe "#exist?" do
    it "returns true" do
      expect(service.exist?(key)).to eq(true)
    end
  end

  describe "error handling (shared by handle_response, exercised via #upload)" do
    def stub_response(code)
      instance_double(HTTParty::Response, code: code)
    end

    it "raises ActiveStorage::FileNotFoundError on 404" do
      allow(described_class).to receive(:put).and_return(stub_response(404))

      expect { service.upload(key, StringIO.new("data")) }
        .to raise_error(ActiveStorage::FileNotFoundError)
    end

    it "raises ActiveStorage::IntegrityError on 422" do
      allow(described_class).to receive(:put).and_return(stub_response(422))

      expect { service.upload(key, StringIO.new("data")) }
        .to raise_error(ActiveStorage::IntegrityError)
    end

    it "raises ActiveStorage::Error on 401" do
      allow(described_class).to receive(:put).and_return(stub_response(401))

      expect { service.upload(key, StringIO.new("data")) }
        .to raise_error(ActiveStorage::Error)
    end

    it "raises ActiveStorage::Error on an unmapped 500" do
      allow(described_class).to receive(:put).and_return(stub_response(500))

      expect { service.upload(key, StringIO.new("data")) }
        .to raise_error(ActiveStorage::Error)
    end
  end
end
