require "rails_helper"

RSpec.describe Hikcentral::AddVehicleJob, type: :job do
  let(:truck) { create(:truck) }
  let(:driver) { create(:driver) }

  describe "#perform" do
    it "calls Hikcentral::AddVehicleService for the given truck and driver" do
      service = instance_double(Hikcentral::AddVehicleService, call: true)
      allow(Hikcentral::AddVehicleService).to receive(:new).with(truck: truck, driver: driver).and_return(service)

      described_class.new.perform(truck_id: truck.id, driver_id: driver.id)

      expect(service).to have_received(:call)
    end

    it "skips a truck that was already synced" do
      truck.update!(hikcentral_synced_at: Time.current)
      allow(Hikcentral::AddVehicleService).to receive(:new)

      described_class.new.perform(truck_id: truck.id, driver_id: driver.id)

      expect(Hikcentral::AddVehicleService).not_to have_received(:new)
    end
  end
end
