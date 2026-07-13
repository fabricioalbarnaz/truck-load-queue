require "rails_helper"

RSpec.describe Truck, type: :model do
  subject { build(:truck) }

  it { is_expected.to validate_presence_of(:plate) }
  it { is_expected.to validate_uniqueness_of(:plate).ignoring_case_sensitivity }

  it "enforces uniqueness regardless of case, since the plate is normalized to upcase" do
    create(:truck, plate: "xyz1234")
    expect(build(:truck, plate: "XYZ1234")).not_to be_valid
  end
  it { is_expected.to have_many(:driver_trucks).dependent(:destroy) }
  it { is_expected.to have_many(:drivers).through(:driver_trucks) }
  it { is_expected.to validate_numericality_of(:capacity).is_greater_than(0).allow_nil }

  it "normalizes the plate to upcase and strips whitespace" do
    truck = build(:truck, plate: " abc1234 ")
    expect(truck.plate).to eq("ABC1234")
  end
end
