module Events
  module Processors
    class TruckDetectedProcessor
      def initialize(event:)
        @event = event
      end

      def call
        Rails.logger.info(
          "[Events::Processors::TruckDetectedProcessor] stub ran for event ##{@event.id} " \
          "(device_id=#{@event.device_id.inspect}, payload=#{@event.payload.inspect})"
        )
        # Intentionally a no-op beyond logging — turning this into a started Visit is a
        # separate, later plan. Must not call Visits::CheckInService or create a Visit here.
      end
    end
  end
end
