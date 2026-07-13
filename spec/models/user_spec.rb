require "rails_helper"

RSpec.describe User, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to have_many(:user_roles).dependent(:destroy) }
  it { is_expected.to have_many(:roles).through(:user_roles) }

  describe "#role?" do
    it "is true when the user holds that role" do
      user = create(:user)
      user.roles << create(:role, :admin)

      expect(user.role?(:admin)).to be true
      expect(user.role?(:fila)).to be false
    end
  end

  describe "#admin?" do
    it "delegates to role?(:admin)" do
      user = create(:user)
      user.roles << create(:role, :admin)

      expect(user.admin?).to be true
    end
  end
end
