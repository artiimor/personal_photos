require 'rails_helper'

RSpec.describe Photo, type: :model do
  describe "validations" do
    it { should validate_presence_of(:name) }
  end

  describe "associations" do
    it { should belong_to(:user) }
  end
end
