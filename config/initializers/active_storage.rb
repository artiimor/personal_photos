Rails.application.config.to_prepare do
  ActiveStorage::VariantWithRecord.prepend(Module.new do
    def create_or_find_record(image:)
      super(image: image.merge(key: "#{blob.key.split("/", 2).first}/#{SecureRandom.uuid}"))
    end
  end)
end
