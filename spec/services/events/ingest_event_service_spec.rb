require "rails_helper"

RSpec.describe Events::IngestEventService do
  describe "#call" do
    it "creates a pending event and enqueues processing for valid input" do
      expect {
        expect {
          described_class.new(event_type: "truck_detected", payload: { plate: "ABC1D23" }, device_id: "gate-cam-01").call
        }.to have_enqueued_job(Events::ProcessEventJob)
      }.to change(Event, :count).by(1)

      event = Event.last
      expect(event).to be_persisted
      expect(event).to be_pending
      expect(event.event_type).to eq("truck_detected")
      expect(event.device_id).to eq("gate-cam-01")
      expect(event.payload).to eq("plate" => "ABC1D23")
      expect(event.received_at).to be_present
    end

    it "parses a valid occurred_at" do
      event = described_class.new(event_type: "truck_detected", payload: {}, occurred_at: "2026-08-06T14:32:10Z").call

      expect(event.occurred_at).to eq(Time.zone.parse("2026-08-06T14:32:10Z"))
    end

    it "leaves occurred_at nil when it can't be parsed" do
      event = described_class.new(event_type: "truck_detected", payload: {}, occurred_at: "not-a-time").call

      expect(event.occurred_at).to be_nil
    end

    it "does not save or enqueue anything for a blank event_type" do
      expect {
        expect {
          described_class.new(event_type: "", payload: {}).call
        }.not_to have_enqueued_job(Events::ProcessEventJob)
      }.not_to change(Event, :count)
    end

    it "returns the unpersisted record with errors for a blank event_type" do
      event = described_class.new(event_type: "", payload: {}).call

      expect(event).not_to be_persisted
      expect(event.errors[:event_type]).to be_present
    end
  end
end
