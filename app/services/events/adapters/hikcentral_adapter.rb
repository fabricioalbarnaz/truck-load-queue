module Events
  module Adapters
    # Normalizes HikCentral's OnEventNotify envelope into the app's generic events pipeline.
    # Only ANPR "License Plate Information Uploading" events (eventType 131622, per the
    # HikCentral OpenAPI guide) with a readable plate matter right now — everything else
    # (other event types, or a 131622 event where the camera couldn't read the plate, reported
    # as plateNo "Unknown") is dropped without creating an Event record, since a live camera
    # feed emits a lot of noise we don't want cluttering the events table.
    class HikcentralAdapter
      RELEVANT_EVENT_TYPE = 131622
      UNKNOWN_PLATE = "Unknown"

      class InvalidPushError < StandardError; end

      def initialize(raw_body)
        @raw_body = raw_body
      end

      def call
        raw_events = @raw_body.dig("params", "events")
        raise InvalidPushError, "missing params.events array" unless raw_events.is_a?(Array)

        accepted = []
        skipped_count = 0

        raw_events.each do |raw_event|
          if relevant?(raw_event)
            accepted << ingest(raw_event)
          else
            skipped_count += 1
          end
        end

        { accepted: accepted, skipped_count: skipped_count }
      end

      private

      def relevant?(raw_event)
        raw_event["eventType"].to_i == RELEVANT_EVENT_TYPE && raw_event.dig("data", "plateNo") != UNKNOWN_PLATE
      end

      def ingest(raw_event)
        Events::IngestEventService.new(
          event_type: "truck_detected",
          device_id: raw_event["srcIndex"],
          occurred_at: raw_event["happenTime"],
          payload: { "plate" => raw_event.dig("data", "plateNo") }
        ).call
      end
    end
  end
end
