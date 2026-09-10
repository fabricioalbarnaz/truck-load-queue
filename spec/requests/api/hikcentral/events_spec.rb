require "rails_helper"

RSpec.describe "Api::Hikcentral::Events", type: :request do
  let(:token) { ENV["EVENTS_INGEST_TOKEN"] }

  def anpr_event(event_type: 131622, plate_no: "EZL3101")
    {
      eventId: "F365E56C56B44DF39F1CE1CD533A9054",
      srcIndex: "21",
      srcType: "camera",
      srcName: " iDS-2CD7A46G2-IZHSY",
      eventType: event_type,
      status: 0,
      happenTime: "2026-09-08T21:31:47-03:00",
      data: { plateNo: plate_no }
    }
  end

  def push_with(events)
    {
      method: "OnEventNotify",
      params: { sendTime: "2026-09-08T21:32:07-03:00", ability: "event_veh", events: events },
      isHistory: 0,
      event: {}
    }
  end

  # HikCentral posts real JSON (numeric fields like eventType stay numbers), so these specs
  # send `as: :json` to match — the default form-encoded test post would stringify eventType
  # and silently exercise a different code path than production traffic does.
  describe "POST /api/hikcentral/events" do
    it "returns 401 when no token is given" do
      post "/api/hikcentral/events", params: push_with([ anpr_event ]), as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the wrong token is given" do
      post "/api/hikcentral/events", params: push_with([ anpr_event ]), as: :json,
                                      headers: { "HTTP_TOKEN" => "wrong-token" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 202, persists a truck_detected Event, and reports it as accepted" do
      expect {
        post "/api/hikcentral/events", params: push_with([ anpr_event ]), as: :json,
                                        headers: { "HTTP_TOKEN" => token }
      }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body
      expect(body["skipped"]).to eq(0)
      expect(body["accepted"].sole["status"]).to eq("pending")

      event = Event.find(body["accepted"].sole["id"])
      expect(event.event_type).to eq("truck_detected")
      expect(event.device_id).to eq("21")
      expect(event.payload).to eq("plate" => "EZL3101")
    end

    it "returns 202 and skips, without persisting, an event with an unrecognized eventType" do
      expect {
        post "/api/hikcentral/events", params: push_with([ anpr_event(event_type: 197391) ]), as: :json,
                                        headers: { "HTTP_TOKEN" => token }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body
      expect(body["accepted"]).to be_empty
      expect(body["skipped"]).to eq(1)
    end

    it "returns 202 and skips, without persisting, a plateNo of Unknown" do
      expect {
        post "/api/hikcentral/events", params: push_with([ anpr_event(plate_no: "Unknown") ]), as: :json,
                                        headers: { "HTTP_TOKEN" => token }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["skipped"]).to eq(1)
    end

    it "returns 422 for a malformed body with no params.events array" do
      expect {
        post "/api/hikcentral/events", params: { method: "OnEventNotify", params: {} }, as: :json,
                                        headers: { "HTTP_TOKEN" => token }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end
  end
end
