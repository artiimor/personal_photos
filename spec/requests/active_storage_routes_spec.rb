require 'rails_helper'

# Stock ActiveStorage routes serve any blob to whoever holds its signed id, bypassing auth.
# They are disabled (config.active_storage.draw_routes = false); only our own routes exist.
RSpec.describe "ActiveStorage routes" do
  {
    get: [
      "/rails/active_storage/blobs/redirect/signed-id/photo.jpg",
      "/rails/active_storage/blobs/proxy/signed-id/photo.jpg",
      "/rails/active_storage/representations/redirect/signed-id/variation/photo.jpg",
      "/rails/active_storage/representations/proxy/signed-id/variation/photo.jpg",
      "/rails/active_storage/disk/encoded-key/photo.jpg"
    ],
    put: [ "/rails/active_storage/disk/encoded-token" ]
  }.each do |method, paths|
    paths.each do |path|
      it "does not route #{method.upcase} #{path}" do
        expect { Rails.application.routes.recognize_path(path, method: method) }
          .to raise_error(ActionController::RoutingError)
      end
    end
  end

  it "routes direct uploads to our authenticated controller" do
    expect(Rails.application.routes.recognize_path("/rails/active_storage/direct_uploads", method: :post))
      .to include(controller: "custom_direct_uploads", action: "create")
  end
end
