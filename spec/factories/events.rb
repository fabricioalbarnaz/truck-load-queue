FactoryBot.define do
  factory :event do
    event_type { "truck_detected" }
    payload { { plate: "ABC1D23" } }
    device_id { "gate-cam-01" }
    received_at { Time.current }

    trait :failed do
      status { "failed" }
      error_message { "boom" }
    end

    trait :processed do
      status { "processed" }
      processed_at { Time.current }
    end
  end
end
