require "rails_helper"

RSpec.describe Event, type: :model do
  subject { build(:event) }

  it {
    is_expected.to define_enum_for(:status)
      .with_values(pending: "pending", processed: "processed", failed: "failed")
      .backed_by_column_of_type(:string)
  }

  it { is_expected.to validate_presence_of(:event_type) }
  it { is_expected.to validate_presence_of(:received_at) }

  describe ".for_type" do
    it "returns only events of the given type" do
      matching = create(:event, event_type: "truck_detected")
      create(:event, event_type: "other_type")

      expect(Event.for_type("truck_detected")).to contain_exactly(matching)
    end
  end
end
