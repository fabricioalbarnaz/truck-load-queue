require "rails_helper"

RSpec.describe "Live plate autofill on check-in from a truck_detected event", type: :system do
  let(:registration_user) { create(:user).tap { |u| u.roles << create(:role, :registration_operator) } }
  let(:truck) { create(:truck) }

  it "overwrites the plate field live and auto-triggers the existing lookup" do
    truck

    sign_in_via_form(registration_user)
    visit registration_visits_path

    fill_in "visit_truck_plate", with: "should be overwritten"

    perform_enqueued_jobs do
      Events::IngestEventService.new(
        event_type: "truck_detected",
        device_id: "gate-cam-01",
        occurred_at: Time.current.iso8601,
        payload: { "plate" => truck.plate }
      ).call
    end

    expect(page).to have_field("visit_truck_plate", with: truck.plate, wait: 10)
    expect(page).to have_field("visit_truck_model", with: truck.model, wait: 10)
    expect(page).to have_field("visit_truck_capacity", with: truck.capacity.to_s, wait: 10)
  end
end
