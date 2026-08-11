require "rails_helper"

RSpec.describe Events::ProcessEventJob, type: :job do
  describe "#perform" do
    it "marks the event processed when the processor succeeds" do
      event = create(:event, event_type: "truck_detected")

      Events::ProcessEventJob.new.perform(event_id: event.id)

      event.reload
      expect(event).to be_processed
      expect(event.processed_at).to be_present
    end

    it "marks the event failed and does not re-raise for an unrecognized event_type" do
      event = create(:event, event_type: "unregistered_type")

      expect { Events::ProcessEventJob.new.perform(event_id: event.id) }.not_to raise_error

      event.reload
      expect(event).to be_failed
      expect(event.error_message).to be_present
    end

    it "marks the event failed and re-raises when the processor blows up" do
      event = create(:event, event_type: "truck_detected")
      allow_any_instance_of(Events::Processors::TruckDetectedProcessor).to receive(:call).and_raise(StandardError, "kaboom")

      expect { Events::ProcessEventJob.new.perform(event_id: event.id) }.to raise_error(StandardError, "kaboom")

      event.reload
      expect(event).to be_failed
      expect(event.error_message).to eq("kaboom")
    end
  end
end
