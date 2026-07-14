FactoryBot.define do
  factory :visit do
    driver
    truck
    checked_in_by factory: :user
    status { "in_yard" }
    entered_yard_at { Time.current }

    trait :queued do
      status { "queued" }
      order_issued_at { Time.current }
    end

    trait :loading do
      status { "loading" }
      order_issued_at { Time.current }
      loading_started_at { Time.current }
    end

    trait :finished do
      status { "finished" }
      order_issued_at { Time.current }
      loading_started_at { Time.current }
      finished_at { Time.current }
    end
  end
end
