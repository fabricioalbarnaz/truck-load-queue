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

    context "with a new (unsaved) driver" do
      it "persists the new driver and creates the visit" do
        new_driver = build(:driver)

        expect {
          expect {
            described_class.new(driver: new_driver, truck: truck, checked_in_by: operator).call
          }.to change(Driver, :count).by(1)
        }.to change(Visit, :count).by(1)

        expect(new_driver).to be_persisted
      end

      it "creates the driver_truck pairing for the newly persisted driver" do
        new_driver = build(:driver)

        expect {
          described_class.new(driver: new_driver, truck: truck, checked_in_by: operator).call
        }.to change(DriverTruck, :count).by(1)
      end

      it "does not persist the driver or the visit when the new driver is invalid" do
        new_driver = Driver.new

        expect {
          expect {
            visit = described_class.new(driver: new_driver, truck: truck, checked_in_by: operator).call
            expect(visit).not_to be_persisted
          }.not_to change(Driver, :count)
        }.not_to change(Visit, :count)

        expect(new_driver).not_to be_persisted
        expect(new_driver.errors[:name]).to be_present
      end
    end

    context "with a new (unsaved) truck" do
      it "persists the new truck and creates the visit" do
        new_truck = build(:truck)

        expect {
          expect {
            described_class.new(driver: driver, truck: new_truck, checked_in_by: operator).call
          }.to change(Truck, :count).by(1)
        }.to change(Visit, :count).by(1)

        expect(new_truck).to be_persisted
      end

      it "does not persist the truck or the visit when the new truck is invalid" do
        new_truck = Truck.new

        expect {
          expect {
            visit = described_class.new(driver: driver, truck: new_truck, checked_in_by: operator).call
            expect(visit).not_to be_persisted
          }.not_to change(Truck, :count)
        }.not_to change(Visit, :count)

        expect(new_truck).not_to be_persisted
        expect(new_truck.errors[:plate]).to be_present
      end
    end

    context "with both a new driver and a new truck" do
      it "persists both and creates the visit" do
        new_driver = build(:driver)
        new_truck = build(:truck)

        described_class.new(driver: new_driver, truck: new_truck, checked_in_by: operator).call

        expect(new_driver).to be_persisted
        expect(new_truck).to be_persisted
      end

      it "rolls back the new driver when the new truck is invalid" do
        new_driver = build(:driver)
        new_truck = Truck.new

        expect {
          visit = described_class.new(driver: new_driver, truck: new_truck, checked_in_by: operator).call
          expect(visit).not_to be_persisted
        }.not_to change(Driver, :count)

        expect(new_driver).not_to be_persisted
        expect(new_truck.errors[:plate]).to be_present
      end
    end
  end
end
