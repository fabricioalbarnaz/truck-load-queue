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
  end
end
