require "rails_helper"

RSpec.describe DriverTruck, type: :model do
  subject { build(:driver_truck) }

  it { is_expected.to belong_to(:driver) }
  it { is_expected.to belong_to(:truck) }
  it { is_expected.to validate_uniqueness_of(:truck_id).scoped_to(:driver_id) }
end
