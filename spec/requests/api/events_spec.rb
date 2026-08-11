require "rails_helper"

RSpec.describe "Api::Events", type: :request do
  let(:token) { ENV["EVENTS_INGEST_TOKEN"] }
  let(:valid_params) do
    { event_type: "truck_detected", device_id: "gate-cam-01", data: { plate: "ABC1D23" } }
  end

  describe "POST /api/events" do
    it "returns 401 when no token is given" do
      post "/api/events", params: valid_params

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the wrong token is given" do
      post "/api/events", params: valid_params, headers: { "Authorization" => "Bearer wrong-token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 202 and persists a pending event for a valid, recognized event_type" do
      expect {
        expect {
          post "/api/events", params: valid_params, headers: { "Authorization" => "Bearer #{token}" }
        }.to have_enqueued_job(Events::ProcessEventJob)
      }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body
      expect(body["status"]).to eq("pending")

      event = Event.find(body["id"])
      expect(event.event_type).to eq("truck_detected")
      expect(event.device_id).to eq("gate-cam-01")
      expect(event.payload).to eq("plate" => "ABC1D23")
    end

    it "returns 422 and persists nothing for a blank event_type" do
      expect {
        post "/api/events", params: valid_params.merge(event_type: ""), headers: { "Authorization" => "Bearer #{token}" }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns 202 and persists the event for an unrecognized event_type, per accept-and-fail-async" do
      expect {
        post "/api/events", params: valid_params.merge(event_type: "something_unknown"),
                             headers: { "Authorization" => "Bearer #{token}" }
      }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:accepted)
    end
  end
end
