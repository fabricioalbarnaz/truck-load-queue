module Events
  class IngestEventService
    def initialize(event_type:, payload:, device_id: nil, occurred_at: nil)
      @event_type = event_type.to_s
      @payload = payload
      @device_id = device_id
      @occurred_at = occurred_at
    end

    def call
      event = Event.new(
        event_type: @event_type, payload: @payload, device_id: @device_id,
        occurred_at: parsed_occurred_at, received_at: Time.current
      )
      Events::ProcessEventJob.perform_later(event_id: event.id) if event.save
      event
    end

    private

    def parsed_occurred_at
      Time.zone.parse(@occurred_at.to_s) if @occurred_at.present?
    rescue ArgumentError
      nil
    end
  end
end
