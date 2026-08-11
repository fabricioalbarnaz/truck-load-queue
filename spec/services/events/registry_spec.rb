require "rails_helper"

RSpec.describe Events::Registry do
  describe ".processor_for" do
    it "resolves the registered processor for a known event_type" do
      expect(Events::Registry.processor_for("truck_detected"))
        .to eq(Events::Processors::TruckDetectedProcessor)
    end

    it "raises Events::UnknownEventTypeError for an unregistered event_type" do
      expect { Events::Registry.processor_for("unknown_thing") }
        .to raise_error(Events::UnknownEventTypeError)
    end
  end
end
