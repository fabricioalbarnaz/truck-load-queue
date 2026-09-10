require "rails_helper"

RSpec.describe Events::Adapters::HikcentralAdapter do
  def push_with(events)
    {
      "method" => "OnEventNotify",
      "params" => {
        "sendTime" => "2026-09-08T21:32:07-03:00",
        "ability" => "event_veh",
        "events" => events
      },
      "isHistory" => 0,
      "event" => {}
    }
  end

  def anpr_event(event_type: 131622, plate_no: "EZL3101", src_index: "21", happen_time: "2026-09-08T21:31:47-03:00")
    {
      "eventId" => "F365E56C56B44DF39F1CE1CD533A9054",
      "srcIndex" => src_index,
      "srcType" => "camera",
      "srcName" => " iDS-2CD7A46G2-IZHSY",
      "eventType" => event_type,
      "status" => 0,
      "happenTime" => happen_time,
      "data" => { "plateNo" => plate_no }
    }
  end

  describe "#call" do
    it "ingests a 131622 event with a readable plate as a truck_detected Event" do
      result = nil

      expect {
        result = described_class.new(push_with([ anpr_event ])).call
      }.to change(Event, :count).by(1)

      expect(result[:skipped_count]).to eq(0)
      event = result[:accepted].sole
      expect(event.event_type).to eq("truck_detected")
      expect(event.device_id).to eq("21")
      expect(event.payload).to eq("plate" => "EZL3101")
      expect(event.occurred_at).to eq(Time.zone.parse("2026-09-08T21:31:47-03:00"))
    end

    it "skips an event whose eventType is not 131622" do
      result = nil

      expect {
        result = described_class.new(push_with([ anpr_event(event_type: 197391) ])).call
      }.not_to change(Event, :count)

      expect(result[:accepted]).to be_empty
      expect(result[:skipped_count]).to eq(1)
    end

    it "skips a 131622 event whose plateNo is Unknown" do
      result = nil

      expect {
        result = described_class.new(push_with([ anpr_event(plate_no: "Unknown") ])).call
      }.not_to change(Event, :count)

      expect(result[:accepted]).to be_empty
      expect(result[:skipped_count]).to eq(1)
    end

    it "evaluates multiple events in one push independently" do
      events = [
        anpr_event(plate_no: "AAA1111"),
        anpr_event(event_type: 197391),
        anpr_event(plate_no: "Unknown"),
        anpr_event(plate_no: "BBB2222", src_index: "22")
      ]

      result = nil
      expect {
        result = described_class.new(push_with(events)).call
      }.to change(Event, :count).by(2)

      expect(result[:accepted].map { |e| e.payload["plate"] }).to contain_exactly("AAA1111", "BBB2222")
      expect(result[:skipped_count]).to eq(2)
    end

    it "raises InvalidPushError when params.events is missing" do
      expect {
        described_class.new({ "method" => "OnEventNotify", "params" => {} }).call
      }.to raise_error(Events::Adapters::HikcentralAdapter::InvalidPushError)
    end
  end
end
