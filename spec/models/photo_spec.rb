require 'rails_helper'

RSpec.describe Photo, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:path) }
    it { should validate_presence_of(:file_type) }
  end

  describe "associations" do
    it { should belong_to(:user) }
  end
end
