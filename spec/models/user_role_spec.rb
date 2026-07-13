require "rails_helper"

RSpec.describe UserRole, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:role) }

  it "does not allow the same user to hold the same role twice" do
    user = create(:user)
    role = create(:role, :admin)
    create(:user_role, user: user, role: role)

    duplicate = build(:user_role, user: user, role: role)

    expect(duplicate).not_to be_valid
  end
end
