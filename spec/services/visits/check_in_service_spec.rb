require "rails_helper"

RSpec.describe Visits::CheckInService do
  let(:driver) { create(:driver) }
  let(:truck) { create(:truck) }
  let(:operator) { create(:user) }

  describe "#call" do
    it "creates an in_yard visit checked in by the given user" do
      visit = described_class.new(driver: driver, truck: truck, checked_in_by: operator).call

      expect(visit).to be_persisted
      expect(visit).to be_in_yard
      expect(visit.checked_in_by).to eq(operator)
      expect(visit.entered_yard_at).to be_present
    end

    it "creates the driver_truck pairing when it doesn't exist yet" do
      expect {
        described_class.new(driver: driver, truck: truck, checked_in_by: operator).call
      }.to change(DriverTruck, :count).by(1)

      expect(driver.trucks.reload).to include(truck)
    end

    it "does not duplicate the pairing when it already exists" do
      create(:driver_truck, driver: driver, truck: truck)

      expect {
        described_class.new(driver: driver, truck: truck, checked_in_by: operator).call
      }.not_to change(DriverTruck, :count)
    end

    it "reactivates a soft-disabled driver_truck pairing" do
      pairing = create(:driver_truck, driver: driver, truck: truck, active: false)

      described_class.new(driver: driver, truck: truck, checked_in_by: operator).call

      expect(pairing.reload.active).to be true
    end

    it "does not create a visit when the driver already has an active visit" do
      create(:visit, driver: driver)

      visit = described_class.new(driver: driver, truck: create(:truck), checked_in_by: operator).call

      expect(visit).not_to be_persisted
      expect(visit.errors[:driver]).to be_present
    end

    it "does not create a visit when the truck already has an active visit" do
      create(:visit, truck: truck)

      visit = described_class.new(driver: create(:driver), truck: truck, checked_in_by: operator).call

      expect(visit).not_to be_persisted
      expect(visit.errors[:truck]).to be_present
    end
  end
end
