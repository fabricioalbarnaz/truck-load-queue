module Events
  class ProcessEventJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(event_id:)
      event = Event.find(event_id)
      Events::Registry.processor_for(event.event_type).new(event: event).call
      event.update!(status: :processed, processed_at: Time.current, error_message: nil)
    rescue Events::UnknownEventTypeError => e
      event.update!(status: :failed, error_message: e.message) # permanent, no retry
    rescue StandardError => e
      event&.update!(status: :failed, error_message: e.message)
      raise # re-raise so retry_on's polynomial backoff still engages
    end
  end
end
