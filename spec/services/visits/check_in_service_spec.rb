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

    context "with an order_number" do
      it "issues the order immediately, sending the visit straight to loading when the queue is empty" do
        visit = described_class.new(
          driver: driver, truck: truck, checked_in_by: operator, order_number: "OC-123"
        ).call

        expect(visit).to be_persisted
        expect(visit).to be_loading
        expect(visit.order_number).to eq("OC-123")
        expect(visit.order_issued_by).to eq(operator)
      end

      it "queues the visit when another one is already loading" do
        create(:visit, :loading)

        visit = described_class.new(
          driver: driver, truck: truck, checked_in_by: operator, order_number: "OC-123"
        ).call

        expect(visit).to be_queued
      end
    end

    context "without an order_number" do
      it "leaves the visit in_yard" do
        visit = described_class.new(driver: driver, truck: truck, checked_in_by: operator).call

        expect(visit).to be_in_yard
        expect(visit.order_number).to be_nil
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

    context "HikCentral vehicle-list sync" do
      it "does not enqueue a sync job when the feature flag is disabled" do
        expect {
          described_class.new(driver: driver, truck: truck, checked_in_by: operator).call
        }.not_to have_enqueued_job(Hikcentral::AddVehicleJob)
      end

      it "enqueues a sync job for a not-yet-synced truck when the feature flag is enabled" do
        create(:feature_flag, :hikcentral, enabled: true)

        expect {
          described_class.new(driver: driver, truck: truck, checked_in_by: operator).call
        }.to have_enqueued_job(Hikcentral::AddVehicleJob).with(truck_id: truck.id, driver_id: driver.id)
      end

      it "does not enqueue a sync job for a truck that was already synced" do
        create(:feature_flag, :hikcentral, enabled: true)
        truck.update!(hikcentral_synced_at: Time.current)

        expect {
          described_class.new(driver: driver, truck: truck, checked_in_by: operator).call
        }.not_to have_enqueued_job(Hikcentral::AddVehicleJob)
      end
    end
  end
end
