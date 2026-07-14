require "rails_helper"

RSpec.describe Notifications::NotifyDriverService do
  describe ".enqueue" do
    it "enqueues a SendNotificationJob for the visit and event" do
      visit = create(:visit, :loading)

      expect {
        described_class.enqueue(visit: visit, event: :your_turn)
      }.to have_enqueued_job(SendNotificationJob).with(visit_id: visit.id, event: "your_turn")
    end
  end

  describe "#call" do
    it "builds the your_turn message and dispatches it through the driver's channel" do
      visit = create(:visit, :loading)

      described_class.new(visit: visit, event: :your_turn).call

      expect(Notifications::Adapters::TestAdapter.messages.size).to eq(1)
      message = Notifications::Adapters::TestAdapter.messages.first
      expect(message[:to]).to eq(visit.driver.phone)
      expect(message[:body]).to include(visit.driver.name)
      expect(message[:body]).to include(visit.truck.plate)
    end
  end
end
