require "rails_helper"

RSpec.describe Events::Processors::TruckDetectedProcessor do
  describe "#call" do
    it "runs without raising" do
      event = create(:event, event_type: "truck_detected")

      expect { described_class.new(event: event).call }.not_to raise_error
    end

    it "does not create a Visit, since wiring this up is a separate, later plan" do
      event = create(:event, event_type: "truck_detected")

      expect { described_class.new(event: event).call }.not_to change(Visit, :count)
    end

    it "broadcasts the normalized plate to the check-in screen" do
      event = create(:event, event_type: "truck_detected", payload: { plate: " abc1d23 " })

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "registration_checkin",
        target: "truck_plate_field",
        partial: "registration/visits/truck_plate_field",
        locals: { plate: "ABC1D23", autofill: true }
      )

      described_class.new(event: event).call
    end

    it "does not broadcast when the payload has no plate" do
      event = create(:event, event_type: "truck_detected", payload: {})

      expect(Turbo::StreamsChannel).not_to receive(:broadcast_replace_to)

      described_class.new(event: event).call
    end
  end
end
