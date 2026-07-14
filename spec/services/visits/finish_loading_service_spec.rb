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

    it "promotes the next queued visit to loading" do
      visit = create(:visit, :loading)
      next_up = create(:visit, :queued, order_issued_at: 1.hour.ago)

      described_class.new(visit: visit, finished_by: operator).call

      expect(next_up.reload).to be_loading
    end

    it "leaves the queue untouched when there is nothing queued" do
      visit = create(:visit, :loading)

      expect {
        described_class.new(visit: visit, finished_by: operator).call
      }.not_to raise_error
    end
  end
end
