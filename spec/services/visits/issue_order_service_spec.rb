require "rails_helper"

RSpec.describe Visits::IssueOrderService do
  let(:operator) { create(:user) }

  describe "#call" do
    it "sends the visit straight to loading when the queue is empty" do
      visit = create(:visit)

      result = nil
      expect {
        result = described_class.new(visit: visit, order_issued_by: operator).call
      }.to have_enqueued_job(SendNotificationJob).with(visit_id: visit.id, event: "your_turn")

      expect(result).to be_loading
      expect(result.order_issued_by).to eq(operator)
      expect(result.order_issued_at).to be_present
      expect(result.loading_started_at).to be_present
    end

    it "queues the visit when another visit is already loading" do
      create(:visit, :loading)
      visit = create(:visit)

      result = nil
      expect {
        result = described_class.new(visit: visit, order_issued_by: operator).call
      }.not_to have_enqueued_job(SendNotificationJob)

      expect(result).to be_queued
      expect(result.loading_started_at).to be_nil
    end

    it "queues the visit when another visit is already queued" do
      create(:visit, :queued)
      visit = create(:visit)

      result = described_class.new(visit: visit, order_issued_by: operator).call

      expect(result).to be_queued
    end
  end
end
