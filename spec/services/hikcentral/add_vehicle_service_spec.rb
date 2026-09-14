require "rails_helper"

RSpec.describe Hikcentral::AddVehicleService do
  let(:truck) { create(:truck, plate: "ABC1D23") }
  let(:driver) { create(:driver, name: "Maria Silva", phone: "+5511999999999") }
  let(:client) { instance_double(Hikcentral::Client) }

  describe "#call" do
    it "calls the HikCentral client with the truck's plate and driver's info, and marks the truck synced" do
      received_args = nil
      allow(client).to receive(:add_vehicle) { |**kwargs| received_args = kwargs }

      described_class.new(truck: truck, driver: driver, client: client).call

      expect(received_args).to include(
        plate_no: "ABC1D23", person_given_name: "Maria Silva", phone_no: "+5511999999999"
      )
      expect(received_args[:expired_date] - received_args[:effective_date])
        .to be_within(3.days.to_i).of(5.years.to_i)
      expect(truck.reload.hikcentral_synced_at).to be_within(2.seconds).of(Time.current)
    end

    it "does not mark the truck synced when the client raises" do
      allow(client).to receive(:add_vehicle).and_raise(Hikcentral::Client::RequestError, "boom")

      expect {
        described_class.new(truck: truck, driver: driver, client: client).call
      }.to raise_error(Hikcentral::Client::RequestError)

      expect(truck.reload.hikcentral_synced_at).to be_nil
    end
  end

  describe ".enqueue" do
    it "enqueues Hikcentral::AddVehicleJob with the truck and driver ids" do
      expect {
        described_class.enqueue(truck: truck, driver: driver)
      }.to have_enqueued_job(Hikcentral::AddVehicleJob).with(truck_id: truck.id, driver_id: driver.id)
    end
  end
end
