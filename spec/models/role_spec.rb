require "rails_helper"

RSpec.describe Role, type: :model do
  subject { build(:role) }

  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:key) }
  it { is_expected.to validate_inclusion_of(:key).in_array(Role::KEYS) }
  it { is_expected.to have_many(:user_roles).dependent(:destroy) }
  it { is_expected.to have_many(:users).through(:user_roles) }
end
