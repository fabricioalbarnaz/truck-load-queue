require "rails_helper"

RSpec.describe Visits::PromoteNextService do
  describe "#call" do
    it "does nothing when there is no queued visit" do
      expect {
        expect(described_class.new.call).to be_nil
      }.not_to have_enqueued_job(SendNotificationJob)
    end

    it "promotes the earliest-queued visit by order_issued_at, not creation order" do
      later = create(:visit, :queued, order_issued_at: 1.hour.ago)
      earlier = create(:visit, :queued, order_issued_at: 2.hours.ago)

      result = nil
      expect {
        result = described_class.new.call
      }.to have_enqueued_job(SendNotificationJob).with(visit_id: earlier.id, event: "your_turn")

      expect(result).to eq(earlier)
      expect(earlier.reload).to be_loading
      expect(earlier.loading_started_at).to be_present
      expect(later.reload).to be_queued
    end
  end
end
