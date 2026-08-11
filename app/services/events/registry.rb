module Events
  class UnknownEventTypeError < StandardError; end

  class Registry
    PROCESSORS = {
      "truck_detected" => Events::Processors::TruckDetectedProcessor
    }.freeze

    def self.processor_for(event_type)
      PROCESSORS.fetch(event_type.to_s) do
        raise UnknownEventTypeError, "no processor registered for event_type=#{event_type.inspect}"
      end
    end
  end
end
