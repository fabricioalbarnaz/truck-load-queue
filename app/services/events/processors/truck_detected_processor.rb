module Events
  module Processors
    class TruckDetectedProcessor
      def initialize(event:)
        @event = event
      end

      def call
        plate = Truck.normalize_value_for(:plate, @event.payload["plate"])

        if plate.blank?
          Rails.logger.info(
            "[Events::Processors::TruckDetectedProcessor] event ##{@event.id} " \
            "(device_id=#{@event.device_id.inspect}) has no plate in payload=#{@event.payload.inspect} — skipping"
          )
          return
        end

        Turbo::StreamsChannel.broadcast_replace_to(
          "registration_checkin",
          target: "truck_plate_field",
          partial: "registration/visits/truck_plate_field",
          locals: { plate: plate, autofill: true }
        )

        # Intentionally does not go further than filling the check-in form — turning this
        # into a started Visit is a separate, later plan. Must not call
        # Visits::CheckInService or create a Visit here.
      end
    end
  end
end
