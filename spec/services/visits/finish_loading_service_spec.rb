require "rails_helper"

RSpec.describe Visits::FinishLoadingService do
  let(:operator) { create(:user) }

  describe "#call" do
    it "marks the visit as finished, recording who finished it" do
      visit = create(:visit, :loading)

      result = described_class.new(visit: visit, finished_by: operator).call

      expect(result).to be_finished
      expect(result.finished_by).to eq(operator)
      expect(result.finished_at).to be_present
    end

    it "promotes the next queued visit straight to loading when nothing was already getting ready" do
      visit = create(:visit, :loading)
      next_up = create(:visit, :queued, order_issued_at: 1.hour.ago)

      expect {
        described_class.new(visit: visit, finished_by: operator).call
      }.to have_enqueued_job(SendNotificationJob).with(visit_id: next_up.id, event: "your_turn")

      expect(next_up.reload).to be_loading
    end

    it "promotes the getting_ready visit to loading and moves the next queued visit into getting_ready" do
      visit = create(:visit, :loading)
      next_up = create(:visit, :getting_ready, order_issued_at: 1.hour.ago)
      following = create(:visit, :queued, order_issued_at: 30.minutes.ago)

      expect {
        described_class.new(visit: visit, finished_by: operator).call
      }.to have_enqueued_job(SendNotificationJob).with(visit_id: next_up.id, event: "your_turn")
        .and have_enqueued_job(SendNotificationJob).with(visit_id: following.id, event: "get_ready")

      expect(next_up.reload).to be_loading
      expect(following.reload).to be_getting_ready
    end

    it "leaves the queue untouched when there is nothing queued" do
      visit = create(:visit, :loading)

      expect {
        described_class.new(visit: visit, finished_by: operator).call
      }.not_to raise_error
    end
  end
end
