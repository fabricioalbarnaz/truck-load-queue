require "rails_helper"

RSpec.describe Visits::PromoteNextService do
  describe "#call" do
    it "does nothing when the queue is empty" do
      expect {
        expect(described_class.new.call).to be_nil
      }.not_to have_enqueued_job(SendNotificationJob)
    end

    it "promotes the earliest queued visit to loading and the next one to getting_ready" do
      later = create(:visit, :queued, order_issued_at: 1.hour.ago)
      earlier = create(:visit, :queued, order_issued_at: 2.hours.ago)

      result = nil
      expect {
        result = described_class.new.call
      }.to have_enqueued_job(SendNotificationJob).with(visit_id: earlier.id, event: "your_turn")
        .and have_enqueued_job(SendNotificationJob).with(visit_id: later.id, event: "get_ready")

      expect(result).to eq(earlier)
      expect(earlier.reload).to be_loading
      expect(earlier.loading_started_at).to be_present
      expect(later.reload).to be_getting_ready
      expect(later.getting_ready_at).to be_present
    end

    it "promotes the getting_ready visit to loading ahead of any queued visit" do
      getting_ready = create(:visit, :getting_ready, order_issued_at: 2.hours.ago)
      queued = create(:visit, :queued, order_issued_at: 1.hour.ago)

      result = nil
      expect {
        result = described_class.new.call
      }.to have_enqueued_job(SendNotificationJob).with(visit_id: getting_ready.id, event: "your_turn")

      expect(result).to eq(getting_ready)
      expect(getting_ready.reload).to be_loading
      expect(queued.reload).to be_getting_ready
    end

    it "does not fill the getting_ready slot while nothing is loading yet" do
      # A lone queued visit is promoted straight to loading, leaving nothing behind to move up.
      visit = create(:visit, :queued)

      described_class.new.call

      expect(visit.reload).to be_loading
      expect(Visit.getting_ready).not_to exist
    end

    it "leaves the getting_ready slot alone when it is already filled" do
      loading = create(:visit, :loading)
      getting_ready = create(:visit, :getting_ready, order_issued_at: 2.hours.ago)
      queued = create(:visit, :queued, order_issued_at: 1.hour.ago)

      expect {
        described_class.new.call
      }.not_to have_enqueued_job(SendNotificationJob)

      expect(loading.reload).to be_loading
      expect(getting_ready.reload).to be_getting_ready
      expect(queued.reload).to be_queued
    end
  end
end
