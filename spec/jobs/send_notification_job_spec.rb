require "rails_helper"

RSpec.describe SendNotificationJob, type: :job do
  it "notifies the driver for the given visit and event" do
    visit = create(:visit, :loading)

    perform_enqueued_jobs do
      SendNotificationJob.perform_later(visit_id: visit.id, event: "your_turn")
    end

    expect(Notifications::Adapters::TestAdapter.messages.size).to eq(1)
    expect(Notifications::Adapters::TestAdapter.messages.first[:to]).to eq(visit.driver.phone)
  end
end
